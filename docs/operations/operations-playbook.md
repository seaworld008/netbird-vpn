# 运维手册（部署、备份、升级、回滚、排障）

> 本文是自建 NetBird 的日常运维 SOP。服务端默认是官方脚本生成的 Docker Compose 环境，场景路由节点默认是 Linux VM 或 K8S Pod。

## 1. 部署后首次检查

在 NetBird 服务端目录执行：

```bash
docker compose ps
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker compose logs --tail=200
```

从外部电脑检查：

```bash
curl -I https://netbird.example.com
```

客户端检查：

```bash
netbird status
netbird status -d
```

预期：

- Dashboard 能打开。
- 首次访问进入 `/setup` 创建管理员。
- 客户端能显示 `Connected`。
- Dashboard 里能看到 Peer 在线。

## 2. 备份

### 2.1 配置备份

在服务端目录执行：

```bash
set -euo pipefail

BACKUP_DIR="backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
test -f docker-compose.yml
cp docker-compose.yml "$BACKUP_DIR/"
for file in \
  config.yaml \
  dashboard.env \
  proxy.env \
  caddyfile-netbird.txt \
  nginx-netbird.conf \
  npm-advanced-config.txt; do
  if [ -f "$file" ]; then
    cp "$file" "$BACKUP_DIR/"
  fi
done
docker compose config > "$BACKUP_DIR/docker-compose.rendered.yml"
test -s "$BACKUP_DIR/docker-compose.rendered.yml"
find "$BACKUP_DIR" -maxdepth 1 -type f -print | sort
```

后续数据卷、证书卷和配置必须写入同一个 `BACKUP_DIR`。如果换了 shell，会话恢复
前先把 `BACKUP_DIR` 设为上一步实际创建的目录，不能再用新时间戳生成另一个目录。

### 2.2 数据卷备份

先找真实卷名：

```bash
docker volume ls | grep -i netbird
docker volume ls | grep -i traefik
```

备份主数据卷：

```bash
set -euo pipefail

: "${BACKUP_DIR:?set BACKUP_DIR to the configuration backup directory}"
: "${NETBIRD_DATA_VOLUME:?set the exact NetBird data volume name}"
BACKUP_DIR_ABS="$(cd "$BACKUP_DIR" && pwd -P)"
docker volume inspect "$NETBIRD_DATA_VOLUME" >/dev/null
docker run --rm \
  -v "${NETBIRD_DATA_VOLUME}:/data:ro" \
  -v "${BACKUP_DIR_ABS}:/backup" \
  busybox tar czf /backup/netbird_data.tgz -C /data .
test -s "$BACKUP_DIR_ABS/netbird_data.tgz"
```

如果你使用内置 Traefik，也备份证书卷：

```bash
set -euo pipefail

: "${BACKUP_DIR:?set BACKUP_DIR to the configuration backup directory}"
: "${TRAEFIK_CERT_VOLUME:?set the exact Traefik certificate volume name}"
BACKUP_DIR_ABS="$(cd "$BACKUP_DIR" && pwd -P)"
docker volume inspect "$TRAEFIK_CERT_VOLUME" >/dev/null
docker run --rm \
  -v "${TRAEFIK_CERT_VOLUME}:/data:ro" \
  -v "${BACKUP_DIR_ABS}:/backup" \
  busybox tar czf /backup/traefik_letsencrypt.tgz -C /data .
test -s "$BACKUP_DIR_ABS/traefik_letsencrypt.tgz"
```

不要把备份只放在同一台机器上，至少同步到对象存储、NAS 或离线备份位置。

### 2.3 Routing Peer 身份备份

容器化 Routing Peer 的 Setup Key 只用于首次注册。灾备必须保存映射到 `/var/lib/netbird` 的身份目录，不能依赖一个永不过期 Key。

bind mount 示例：

```bash
tar czf "backup/routing-peer-identity-$(date +%Y%m%d-%H%M%S).tgz" \
  -C /data/netbird-client data
chmod 600 backup/routing-peer-identity-*.tgz
tar tzf backup/routing-peer-identity-*.tgz | head
```

身份目录包含 Peer 私钥，备份应加密并放到受控存储。恢复同一身份前必须确认原 Peer 已离线，不能把同一份身份复制给两台同时在线的节点。恢复后不带 Setup Key 启动容器，并核对 NetBird IP、Groups 和 Networks。完整流程见 [云 VPC 容器化 Routing Peer 运维手册](containerized-routing-peer-runbook.md)。

## 3. 升级

### 3.1 固定目标与升级前清单

1. 看 [上游版本状态](../selfhosted/upstream-version-status.md)。
2. 分别阅读 NetBird 与 Dashboard 的 release notes，检查 breaking changes、
   中间版本和迁移要求。
3. 做配置、数据卷、证书和 Routing Peer 身份备份，并验证备份可读。
4. 确认维护窗口、回滚决策点和负责人。
5. 如果是生产环境，先在测试环境验证客户端登录、路由、DNS、Exit Node、
   Reverse Proxy。

独立 Management、Signal、Relay 和外部 IdP 的老部署先按 [Legacy 外部 IdP 部署升级与回滚](legacy-external-idp-upgrade.md) 判断迁移边界，不直接套用新架构迁移工具。

先记录 Compose 中的配置引用和当前实际运行的镜像 ID：

```bash
set -euo pipefail

UPGRADE_DIR="backup/upgrade-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$UPGRADE_DIR"

docker compose config --images \
  | sort -u \
  | tee "$UPGRADE_DIR/images.before.txt"
test -s "$UPGRADE_DIR/images.before.txt"

for id in $(docker compose ps -q); do
  docker inspect \
    --format '{{.Name}} {{.Config.Image}} {{.Image}}' "$id"
done | sort | tee "$UPGRADE_DIR/containers.before.txt"
test -s "$UPGRADE_DIR/containers.before.txt"
```

明确本次目标版本并先检查远端 manifest。以下占位符必须替换为已经从两个官方
`releases/latest` 核对过的 stable 标签：

```bash
set -euo pipefail

NETBIRD_IMAGE_TAG="X.Y.Z"
DASHBOARD_IMAGE_TAG="vX.Y.Z"
test "$NETBIRD_IMAGE_TAG" != "X.Y.Z"
test "$DASHBOARD_IMAGE_TAG" != "vX.Y.Z"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"

for image in \
  "netbirdio/netbird-server:${NETBIRD_IMAGE_TAG}" \
  "netbirdio/dashboard:${DASHBOARD_IMAGE_TAG}" \
  "netbirdio/reverse-proxy:${NETBIRD_IMAGE_TAG}"; do
  docker manifest inspect "$image" |
    jq -e --arg platform "$TARGET_PLATFORM" '
      any(.manifests[]?;
        (.platform.os + "/" + .platform.architecture
          + (if .platform.variant then "/" + .platform.variant else "" end))
        == $platform)
    ' >/dev/null
done
```

上例包含 `reverse-proxy`；仅在确认 Compose 没有 `proxy` 服务时才从列表删去。
目标主机不是 `linux/amd64` 时先把 `TARGET_PLATFORM` 改成实际平台，例如
`linux/arm64`。命令要求安装 `jq`，任何镜像不存在或缺少目标平台都会立即失败。

然后把 `docker-compose.yml` 中的生产镜像改为这些明确标签，重新渲染并保存
目标清单：

```bash
set -euo pipefail

: "${UPGRADE_DIR:?set UPGRADE_DIR to the current upgrade inventory directory}"
docker compose config --images \
  | sort -u \
  | tee "$UPGRADE_DIR/images.target.txt"
test -s "$UPGRADE_DIR/images.target.txt"
```

目标清单必须满足：

- Combined 架构的 `netbird-server` 固定到目标 NetBird 标签。
- 启用 Reverse Proxy 时，Management 侧容器和 `reverse-proxy` 使用同一个
  NetBird 目标标签，并进入同一次升级、验证和回滚。
- Legacy 架构的 Management、Signal、Relay 使用同一个 NetBird 目标标签。
- Dashboard 固定到其独立 release 标签。
- 没有 `latest`、`main` 或省略标签的镜像。
- manifest 包含生产主机所需架构。manifest 存在只证明镜像可拉取，不证明升级
  已通过业务验证。

### 3.2 拉取并只重建明确组件

先确认实际服务名：

```bash
docker compose config --services
```

官方 Combined 架构且启用了 Reverse Proxy 时：

```bash
set -euo pipefail

docker compose pull netbird-server dashboard proxy
docker compose up -d --force-recreate netbird-server dashboard proxy
```

没有启用 Reverse Proxy 时，从两条命令中删去 `proxy`。Legacy 多容器架构使用：

```bash
set -euo pipefail

docker compose pull management dashboard signal relay
docker compose up -d --force-recreate management dashboard signal relay
```

Legacy 架构启用了 Reverse Proxy 时，两条命令都再加入 `proxy`。不要用一次无
组件名的 `docker compose up -d --force-recreate` 顺带重建数据库、监控或其他
共享服务。

### 3.3 升级后核对

```bash
set -euo pipefail

: "${UPGRADE_DIR:?set UPGRADE_DIR to the current upgrade inventory directory}"
docker compose ps

for id in $(docker compose ps -q); do
  docker inspect \
    --format '{{.Name}} {{.Config.Image}} {{.Image}}' "$id"
done | sort | tee "$UPGRADE_DIR/containers.after.txt"
test -s "$UPGRADE_DIR/containers.after.txt"

docker compose logs --tail=300 netbird-server dashboard proxy
curl --fail --show-error --head https://netbird.example.com
netbird status
```

未启用 `proxy` 时从日志命令删去该服务；Legacy 架构则按实际服务名查看
Management、Signal 和 Relay 日志。必须确认：

- 实际运行镜像 ID 与目标清单相符，没有容器仍停在旧镜像。
- Management 与 Proxy 的标签同步，Proxy 已重新连接 Management。
- 日志中的数据库或存储迁移到达成功终态，没有 crash loop。
- Dashboard、Management、Signal 和 Relay 正常，客户端重新连接。
- 启用 Reverse Proxy 时，至少完成一条授权请求、一条非授权请求和后端真实协议
  请求；不能只看 Proxy 容器为 `Up`。

如果涉及路由节点，再验证至少一个真实资源：

```bash
set -euo pipefail

: "${TARGET_IP:?set the routed resource IP}"
: "${TARGET_PORT:?set the routed resource TCP port}"
: "${TARGET_GET_URL:?set a real health or business GET URL, including scheme}"
: "${TARGET_EXPECTED_HTTP:?set the documented expected HTTP status, for example 200}"

nc -vz "$TARGET_IP" "$TARGET_PORT"
HTTP_STATUS="$(
  curl --silent --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    "$TARGET_GET_URL"
)"
printf 'http=%s\n' "$HTTP_STATUS"
test "$HTTP_STATUS" = "$TARGET_EXPECTED_HTTP"
```

`TARGET_GET_URL` 必须是服务真实支持的 GET，而不是为了方便改成 HEAD。若服务的
未认证探测按设计返回 `401`，可以先把该状态作为连通性预期，但它不代表授权成功；
还要使用服务官方客户端或受控的 `0600` 凭据配置完成一条已认证业务 GET，并断言
响应内容。`405` 通常表示方法选错，应改用服务真实协议，不要把它直接判成网络
故障或成功。

## 4. 回滚

先判断升级是否已经修改数据库 schema、嵌入式 IdP 或其他持久存储。若日志或
release notes 表明迁移已执行，不能只把二进制镜像标签降回旧版后继续使用新
数据；旧二进制可能无法读取已迁移的数据结构。此时应按官方 release 的回滚路径
处理，或在维护窗口内把“旧镜像 + 升级前配置 + 升级前数据”作为一个整体恢复。
如果无法安全回退数据，保持服务停止并采用向前修复，不要反复用不同版本启动同一
份存储。

### 4.1 配置回滚

仅当确认没有持久化迁移、问题只来自配置或容器编排时，才只回滚配置：

```bash
set -euo pipefail

: "${BACKUP_DIR:?set the verified upgrade backup directory}"
test -d "$BACKUP_DIR"
test -f "$BACKUP_DIR/docker-compose.yml"

cp "$BACKUP_DIR/docker-compose.yml" .
for file in \
  config.yaml \
  dashboard.env \
  proxy.env \
  caddyfile-netbird.txt \
  nginx-netbird.conf \
  npm-advanced-config.txt; do
  if [ -f "$BACKUP_DIR/$file" ]; then
    cp "$BACKUP_DIR/$file" .
  fi
done
docker compose up -d --force-recreate netbird-server dashboard proxy
docker compose ps
```

未启用 `proxy` 时删去该服务；Legacy 架构按实际服务名明确列出 Management、
Signal、Relay 和 Dashboard。

### 4.2 数据卷回滚

数据回滚会覆盖当前数据，必须在维护窗口内执行。先确认选中的是升级前备份和真实
卷名，并同时恢复与该数据匹配的 Compose 与配置文件：

```bash
set -euo pipefail

: "${BACKUP_DIR:?set the verified upgrade backup directory}"
: "${ACTUAL_NETBIRD_DATA_VOLUME:?set the exact NetBird data volume name}"
BACKUP_DIR_ABS="$(cd "$BACKUP_DIR" && pwd -P)"
test -f "$BACKUP_DIR_ABS/netbird_data.tgz"
test -f "$BACKUP_DIR_ABS/docker-compose.yml"
docker volume inspect "$ACTUAL_NETBIRD_DATA_VOLUME" >/dev/null

docker compose down
cp "$BACKUP_DIR_ABS/docker-compose.yml" .
for file in \
  config.yaml \
  dashboard.env \
  proxy.env \
  caddyfile-netbird.txt \
  nginx-netbird.conf \
  npm-advanced-config.txt; do
  if [ -f "$BACKUP_DIR_ABS/$file" ]; then
    cp "$BACKUP_DIR_ABS/$file" .
  fi
done
docker run --rm \
  -v "${ACTUAL_NETBIRD_DATA_VOLUME}:/data" \
  -v "${BACKUP_DIR_ABS}:/backup:ro" \
  busybox sh -c 'rm -rf /data/* && tar xzf /backup/netbird_data.tgz -C /data'
docker compose up -d
```

### 4.3 场景配置回滚

对于 `Networks`、资源、策略：

1. 先禁用策略。
2. 再禁用或删除资源。
3. 再移除用户组。
4. 最后下线路由节点。

路由节点下线：

```bash
sudo netbird down
sudo systemctl stop netbird
```

## 5. 网络资源不通排障顺序

按这个顺序查，避免来回跳：

### 5.1 客户端侧

```bash
: "${TARGET_IP:?set the target resource IP}"
: "${TARGET_PORT:?set the target resource TCP port}"
: "${TARGET_URL:?set the full target URL, including scheme}"

netbird status
netbird status -d
netbird networks ls
nc -vz "$TARGET_IP" "$TARGET_PORT"
curl --fail --show-error --head "$TARGET_URL"
```

检查：

- 客户端是否在线。
- 客户端是否在正确用户组。
- 是否拿到了目标 Network。
- 端口是否是策略允许的端口。

### 5.2 路由节点侧

```bash
: "${TARGET_IP:?set the target resource IP}"
: "${TARGET_PORT:?set the target resource TCP port}"
: "${TARGET_URL:?set the full target URL, including scheme}"

netbird status
netbird status -d
sysctl net.ipv4.ip_forward
ip route
nc -vz "$TARGET_IP" "$TARGET_PORT"
curl --fail --show-error --head "$TARGET_URL"
```

检查：

- 路由节点是否在线。
- 路由节点是否在正确 routing peer group。
- 路由节点本机是否能访问目标。
- `ip_forward` 是否开启。

如果 Routing Peer 运行在 Kubernetes 内，不要停在这里。继续按
[Kubernetes 集群内 Routing Peer 生产运维手册](kubernetes-routing-peer-runbook.md)
比较上线前后 CNI、宿主机 SNAT、远端 NodePort、业务 Pod 外联和监控
remote-write。`Connected` 不能证明集群原有网络无回归。

### 5.3 服务端 / Dashboard 侧

检查：

- `Networks` 资源是否写对。
- 资源是否在正确资源组。
- 策略源组 / 目标组是否写反。
- 端口是否漏写。
- 默认 `All -> All` 是否造成误放行。

### 5.4 目标服务侧

检查：

```bash
sudo ss -lntp
sudo iptables-save 2>/dev/null | head
sudo nft list ruleset 2>/dev/null | head
```

常见问题：

- 服务只监听 `127.0.0.1`。
- 防火墙未允许路由节点来源。
- 后端白名单仍是旧 VPN 网段。
- HTTPS 证书只签给域名，用户却用 IP 访问。

## 6. Exit Node 排障

客户端：

```bash
netbird status -d
curl https://ifconfig.me
nslookup example.com
```

出口节点：

```bash
curl https://ifconfig.me
sysctl net.ipv4.ip_forward
```

重点检查：

- 是否有 `用户组 -> exit-node 组 -> ICMP` 策略。
- Auto Apply 是否开启，或客户端是否手动选择。
- DNS 是否配置 `ALL` match domain。
- 出口节点公网访问是否正常。

## 7. Reverse Proxy 排障

外部：

```bash
dig +short grafana.proxy.example.com
curl -vk https://grafana.proxy.example.com
```

目标 Peer：

```bash
: "${PEER_LAN_IP:?set the target peer LAN IP}"

netbird status
curl -I http://127.0.0.1:3000
curl --fail --show-error --head "http://${PEER_LAN_IP}:3000"
```

常见问题：

- 发布域名 DNS 未解析到代理入口。
- 目标 Peer 离线。
- Target 端口写错。
- 后端外部 URL 没配置，登录后跳回内网。
- 后端没有配置 trusted proxies。

## 8. 变更记录模板

每次重要变更建议记录：

```markdown
## YYYY-MM-DD NetBird 变更

- 变更人：
- 变更目的：
- 涉及 Network：
- 涉及资源：
- 涉及策略：
- 验证命令：
- 回滚命令：
- 结果：
```

## 9. 最小日常巡检

每天或每周执行：

```bash
docker compose ps
docker compose logs --tail=100
curl -I https://netbird.example.com
```

Dashboard 检查：

- 是否有离线关键路由 Peer。
- 是否有过期或长期未 revoke 的 Setup Key。
- 是否有临时策略未关闭。
- 是否有资源误加入 `All`。
