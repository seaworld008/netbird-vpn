# NetBird 服务器端（Docker Compose）配置速查（零门槛版）

> 场景定位：服务端部署仍使用 Docker Compose；不自己改安装脚本，只修改官方脚本生成后的配置文件。

## 0. 先定义这件事（最重要）

- 你们环境标准：**服务端只用 docker-compose**
- 例外：K8S 网络打通节点/网关不走 server 统一部署，使用 K8S Pod/Node 侧部署（见 `docs/cases/03-kubernetes-connectivity.md`）

## 1. 官方脚本是“入口”，配置文件是“稳定可运维面”

推荐操作流程：

1. 首次环境：执行官方脚本
   
```bash
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh | bash
```

2. 后续变更：只编辑已经生成的 Compose/配置文件，不再改脚本。

## 2. 一套“最少要懂”的配置文件（服务器端）

- `docker-compose.yml`
  - 起服务（通常是 `dashboard`、`netbird-server`，以及按需启用的 `traefik` / `reverse-proxy`）
  - 端口映射与健康检查
  - 镜像版本（固定/更新）

- `config.yaml`
  - 统一服务端配置
  - 包含管理、Signal、Relay、STUN、嵌入式 IdP、存储等核心参数
  - 新版中它替代了旧版的 `management.json` 和 `relay.env`

- `dashboard.env`
  - Dashboard 管理端 API 地址
  - 客户端授权相关地址
  - OIDC 参数（兼容脚本生成值）

- `proxy.env`
  - 仅在启用 NetBird Proxy 时生成
  - 用于代理令牌和代理容器环境变量

- `caddyfile-netbird.txt` / `nginx-netbird.conf` / `npm-advanced-config.txt`
  - 仅在选择外部反向代理时生成
  - 用于把外部 Caddy/Nginx/Nginx Proxy Manager 指向 `dashboard` 和 `netbird-server`

## 3. 常见改动清单（按优先级）

### A. 90% 场景改这几行就够

1. HTTPS 域名：`NETBIRD_DOMAIN`
2. 证书与 80/443 的外网访问
3. STUN 端口策略：`3478/udp`
4. 防火墙白名单（网段/办公网）

### B. 先不改的配置

- `config.yaml` 里未确认兼容性的高级参数
- 未做验证前，不要随意改 `store`、嵌入式 IdP、外部服务覆盖配置

## 4. 不懂参数怎么办（给“初学者”的建议）

- 只改以下 3 类参数：
  - 网络连通：端口、域名、证书路径
  - 访问策略：管理白名单、路由范围
  - 运行稳定：镜像版本、资源限制（如果你有压测）

- 其它参数先沿用官方脚本默认；除非官方文档明确说明需要变更。

## 5. 典型故障快速定位（先看这 3 个）

1. 管理端口打不通：检查 80/443 与域名解析
2. 客户端连不上：检查 `3478/udp` 与 `netbird-server` 是否正常
3. 访问白名单系统失败：确认策略是否“默认拒绝 + 仅放行”后正确下发

## 6. 你可以直接复用的“最短改动模板”

- 服务器端端口变更：只改 `docker-compose.yml` 中 `netbird-server` 与反向代理的端口映射
- 域名变更：`NETBIRD_DOMAIN` 类变量 + 相关 `http://`/`https://` 地址
- 证书变更：优先走 Traefik 或外部反向代理标准流程，不手工拼接旧版证书文件路径

## 7. 新手改配置的标准操作流程

每次改配置都按这个顺序，不要直接边改边重启。

### 7.1 先备份当前文件

在 NetBird 服务端目录执行：

```bash
BACKUP_DIR="backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp docker-compose.yml config.yaml dashboard.env "$BACKUP_DIR"/ 2>/dev/null || true
cp proxy.env caddyfile-netbird.txt nginx-netbird.conf npm-advanced-config.txt "$BACKUP_DIR"/ 2>/dev/null || true
```

确认目录里有备份：

```bash
find backup -maxdepth 2 -type f | sort | tail -20
```

### 7.2 修改域名时要改哪些地方

假设你要把域名从：

```text
old-netbird.example.com
```

改成：

```text
netbird.example.com
```

至少检查这些文件：

```bash
grep -R "old-netbird.example.com" -n docker-compose.yml config.yaml dashboard.env proxy.env 2>/dev/null || true
```

把所有旧域名替换成新域名后，再检查：

```bash
grep -R "netbird.example.com" -n docker-compose.yml config.yaml dashboard.env proxy.env 2>/dev/null || true
```

你需要重点确认：

- Dashboard 访问地址是 `https://netbird.example.com`
- Management / API 地址是 `https://netbird.example.com`
- Signal / Relay / STUN 相关地址没有残留旧域名
- 反向代理配置中的 `server_name`、Host、TLS 域名没有残留旧域名

### 7.3 修改端口时要改哪些地方

新手优先不要改默认端口。确实要改时，按这个顺序：

1. 改 `docker-compose.yml` 的 `ports` 映射。
2. 改云安全组入方向端口。
3. 改服务器本机防火墙。
4. 改反向代理配置。
5. 重启后用 `docker compose ps` 和 `curl` 验证。

默认推荐保留：

```text
80/tcp
443/tcp
3478/udp
```

如果你只改了 `docker-compose.yml`，但没有改云安全组或本机防火墙，外部仍然访问不到。

### 7.4 修改完成后再重启

先做语法和服务检查：

```bash
docker compose config >/tmp/netbird-compose.rendered.yml
docker compose ps
```

再重启：

```bash
docker compose up -d
docker compose ps
```

查看关键日志：

```bash
docker compose logs --tail=200
```

### 7.5 重启后的最小验证

在服务端本机验证：

```bash
curl -I https://netbird.example.com
```

在外部电脑验证：

```bash
curl -I https://netbird.example.com
```

在已安装客户端的机器上验证：

```bash
netbird status
```

预期：

- HTTPS 返回 `200`、`302` 或登录页相关响应。
- 客户端能连接管理端。
- Dashboard 里能看到 Peer 在线。

如果失败，先不要继续改新配置。直接对照备份回滚：

```bash
cp backup/<backup-dir>/docker-compose.yml .
cp backup/<backup-dir>/config.yaml .
cp backup/<backup-dir>/dashboard.env .
docker compose up -d
```
