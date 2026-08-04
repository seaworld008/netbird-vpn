# Legacy 外部 IdP 部署升级与回滚

> 适用场景：早期 NetBird Docker Compose 使用独立 Management、Signal、Relay、Dashboard，并连接外部 IdP 和数据库。目标是在不改变现有账号、密码、Peer 身份和策略的前提下升级 NetBird 核心组件。

## 1. 先识别部署模型

不要看到官方新架构就直接运行迁移脚本。先保存真实拓扑：

```bash
docker compose config > pre-upgrade-compose.rendered.yml
docker compose config --images | sort > pre-upgrade-images.txt
docker compose ps
docker inspect $(docker compose ps -q) > pre-upgrade-containers.json
```

重点确认：

- 身份源是嵌入式还是独立服务。
- 用户数据在 SQLite、PostgreSQL 或其他数据库。
- Management 数据卷和数据库卷的实际名称。
- 反向代理、Coturn、IdP、数据库是否由同一 Compose 管理。
- 官方 combined-container 迁移工具是否明确支持当前身份架构。

若工具不支持外部 IdP 拓扑，优先保留现有架构并原地升级 NetBird 核心组件。强行迁移可能让账号映射、OIDC 配置和用户数据脱节。

## 2. 升级边界

一次变更只处理必要组件：

| 组件 | 本轮动作 | 原因 |
| --- | --- | --- |
| Management / Signal / Relay | 升级到同一稳定版本 | NetBird 核心协议和管理面保持一致 |
| Dashboard | 升级到匹配的稳定版本 | 管理界面与 API 能力匹配 |
| 外部 IdP | 默认保持原版本 | 避免账号、OIDC 和数据库同时迁移 |
| PostgreSQL | 默认保持原版本 | 降低数据变更范围 |
| Caddy / Coturn | 无明确修复需求则保持 | 避免网络入口与核心升级耦合 |

生产 Compose 所有镜像都应有明确标签。保留旧版本也是明确决策，不是遗漏。

## 3. 完整备份

### 3.1 配置和卷清单

```bash
BACKUP_DIR="backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp docker-compose.yml "$BACKUP_DIR"/
cp .env management.json dashboard.env Caddyfile "$BACKUP_DIR"/ 2>/dev/null || true
docker compose config > "$BACKUP_DIR/docker-compose.rendered.yml"
docker compose config --images > "$BACKUP_DIR/images.txt"
docker volume ls > "$BACKUP_DIR/volumes.txt"
```

不要把包含密码或令牌的备份提交到 Git。备份目录权限建议设为 `0700`。

### 3.2 数据库备份

外部 PostgreSQL 示例：

```bash
docker compose exec -T postgres pg_dumpall -U postgres \
  > "$BACKUP_DIR/postgres-all.sql"
test -s "$BACKUP_DIR/postgres-all.sql"
```

SQLite 示例，文件名以现有部署为准：

```bash
sqlite3 /path/to/store.db 'PRAGMA integrity_check;'
sqlite3 /path/to/events.db 'PRAGMA integrity_check;'
```

两条命令都应返回 `ok`。只复制一个正在写入但未校验的数据库文件，不算可恢复备份。

### 3.3 校验清单

```bash
find "$BACKUP_DIR" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "$BACKUP_DIR/SHA256SUMS"
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS)
```

在维护窗口开始前确认备份位于服务器之外的第二存储位置，并记录恢复负责人。

## 4. 生成升级后的 Compose

只修改镜像标签，不改账号、密码、OIDC issuer、client ID、卷名和域名：

```yaml
services:
  dashboard:
    image: netbirdio/dashboard:v2.90.9
  signal:
    image: netbirdio/signal:0.76.1
  relay:
    image: netbirdio/relay:0.76.1
  management:
    image: netbirdio/management:0.76.1
```

先做静态检查：

```bash
docker compose config >/tmp/netbird-upgrade.rendered.yml
docker compose config --images
git diff --no-index backup/<backup-dir>/docker-compose.yml docker-compose.yml || true
```

检查差异时，预期只有计划内的镜像标签和必要兼容字段变化。

## 5. 分阶段发布

```bash
docker compose pull dashboard signal relay management
docker compose up -d --no-deps signal relay management
docker compose ps
docker compose logs --since=10m --tail=300 signal relay management
docker compose up -d --no-deps dashboard
```

服务名要按现有 Compose 调整。不要在包含其他业务容器的目录执行 `down -v`，也不要使用会误删其他 Compose 项目容器的 `--remove-orphans`。

## 6. 验收矩阵

| 层级 | 验证 | 通过标准 |
| --- | --- | --- |
| 容器 | `docker compose ps` | 目标组件运行且无重启循环 |
| 管理面 | 登录 Dashboard | 原账号、组、策略、网络资源完整 |
| Peer | `netbird status` | 原 Peer 身份、IP 和连接正常 |
| 路由 | 访问授权内网 HTTPS/TCP | 真实业务协议成功 |
| 拒绝 | 非授权 Peer 访问同一目标 | 请求失败 |
| 数据面 | 对比 Routing Peer 传输计数 | 请求后计数增长 |
| 身份 | 新开无痕登录流程 | OIDC/MFA 正常，不依赖旧会话 |

不要只用 `ping` 判定失败。云主机或目标服务可能禁用 ICMP，但 TCP 端口仍然正常。

## 7. 回滚

触发条件包括持续重启、登录失败、策略丢失、既有 Peer 大面积离线或关键资源不可达。

1. 停止继续升级其他组件。
2. 恢复升级前 Compose 和配置。
3. 用原固定标签重新创建核心容器。
4. 若出现数据格式或身份数据异常，再按已验证备份恢复数据库/卷。
5. 重复完整验收矩阵。

```bash
cp backup/<backup-dir>/docker-compose.yml .
docker compose config
docker compose up -d
docker compose ps
```

不要默认回滚数据库。先确认升级是否真的写入了不兼容数据格式，避免用旧备份覆盖维护窗口后的有效变更。

## 8. 升级记录模板

```text
变更时间：
升级前 NetBird / Dashboard：
升级后 NetBird / Dashboard：
保留版本的外围组件：
备份路径与 SHA256 校验：
升级组件：
授权链路结果：
非授权链路结果：
异常与处置：
回滚点：
执行人 / 复核人：
```

官方参考：

- https://docs.netbird.io/selfhosted/maintenance/upgrade
- https://docs.netbird.io/selfhosted/maintenance/backup
- https://docs.netbird.io/selfhosted/migration/combined-container
