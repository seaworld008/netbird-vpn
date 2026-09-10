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

3. 首次生成后立即把生产镜像固定到已验证版本：

```bash
docker compose config --images
```

输出中不应出现漂移标签。官方脚本的 `releases/latest` 是安装入口，不等于允许 Compose 使用不固定版本。

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
: "${BACKUP_DIR:?set the verified backup directory}"
cp "$BACKUP_DIR/docker-compose.yml" .
cp "$BACKUP_DIR/config.yaml" .
cp "$BACKUP_DIR/dashboard.env" .
docker compose up -d
```

## 8. 生产镜像标签清单

本次核对的稳定基线是 NetBird `0.78.1`、Dashboard `v2.92.0`。新安装使用
combined `netbird-server`；下面只展示标签写法，不是可直接覆盖现有拓扑的完整
Compose。本仓库已实测 `v0.78.1` 的存量外部 IdP 控制面与 Routing Peer 升级；
组合容器的新装与 Reverse Proxy 未在本轮部署，生产使用前仍要在自己的测试环境完成备份、升级和回归：

```yaml
services:
  dashboard:
    image: netbirdio/dashboard:v2.92.0
  netbird-server:
    image: netbirdio/netbird-server:0.78.1
```

升级前后都保存镜像清单：

```bash
docker compose config --images | sort | tee compose-images.txt
docker compose images
```

只有存量 Legacy 多容器环境才更新独立 `management`、`signal`、`relay`。同一
Legacy 部署中可以保留经过验证的 Caddy、Coturn、PostgreSQL 和外部 IdP 版本。
不要把一次 NetBird 核心升级扩大成所有基础组件同时升级。

## 9. Routing Peer 使用独立 Compose 项目和持久身份

把路由节点与服务端 Compose 分开，避免更新服务端时误删或重建数据平面。示例：

```yaml
version: "2.4"

services:
  routing-peer:
    image: netbirdio/netbird:0.78.1
    container_name: netbird-routing-peer
    restart: unless-stopped
    networks:
      - netbird-routing
    ports:
      - "51820:51820/udp"
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - /data/netbird-client/data:/var/lib/netbird
    environment:
      NB_MANAGEMENT_URL: https://netbird.example.com
      NB_SETUP_KEY: ${NB_SETUP_KEY:-}
      NB_USE_NETSTACK_MODE: "true"
    healthcheck:
      test:
        - CMD-SHELL
        - >-
          status="$$(netbird status 2>&1)" &&
          echo "$$status" | grep -q "Management: Connected" &&
          echo "$$status" | grep -q "Interface type: Userspace"
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

networks:
  netbird-routing:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.250.0/24

```

在承载其他 Docker 业务的主机上，独立 bridge 网络和
`NB_USE_NETSTACK_MODE=true` 必须同时使用：前者隔离宿主机网络命名空间，后者
让 NetBird 数据面使用 Userspace。只开启 Netstack 但仍使用 host 网络，NetBird
仍可能修改宿主机 nftables / iptables，导致其他 bridge 容器的 DNS、SNAT 或外联
异常。固定子网只是示例，上线前必须确认它不与 VPC、宿主机路由、其他 Docker
网络和客户端 LAN 重叠。

首次注册时临时传入 Setup Key：

```bash
NB_SETUP_KEY='NBSETUP-EXAMPLE-REPLACE-ME' docker compose up -d
docker compose exec routing-peer netbird status
```

确认 Peer 已注册后，不把 Setup Key 留在 `.env`、Compose、Shell history 或仓库中。后续重建依赖持久卷中的身份：

```bash
unset NB_SETUP_KEY
docker compose up -d --force-recreate routing-peer
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' \
  netbird-routing-peer | grep '^NB_SETUP_KEY='
```

Setup Key 过期只影响注册新 Peer，不影响已经注册的 Peer。长期可恢复性来自 `/data/netbird-client/data`，不是来自一个永不过期 Key。无 Key 重建后应确认 NetBird IP、Groups 和 Networks 与重建前一致。

注意：

- 升级某个 Compose 项目时不要附带 `--remove-orphans` 去影响另一项目。
- 独立命名卷或明确 bind mount 必须有备份；删除身份数据会丢失 Routing Peer 身份。
- 路由节点要开启 `net.ipv4.ip_forward=1`。
- 运行后必须确认 `Interface type: Userspace`，并回归同机业务容器的 DNS 和真实
  TCP 外联；`netbird status` 仅显示 Connected 不足以证明无副作用。
- `Masquerade` 默认开启可减少目标内网的回程路由配置；关闭时必须在 VPC 路由表中配置返回 NetBird 网段的路由。
- Docker Compose v1 若在重建时遇到容器名冲突，先核对容器归属，再仅停止并删除该 Routing Peer 容器。不要使用 `down -v` 或跨项目的 `--remove-orphans`。

完整的 `/data/netbird-client` 部署、旧 Compose v1 兼容重建和双云验收流程见 [云 VPC 容器化 Routing Peer 运维手册](../operations/containerized-routing-peer-runbook.md)。

## 10. 变更前后验收

```bash
docker compose config >/tmp/netbird-compose.rendered.yml
docker compose config --images
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --since=10m --tail=300
```

除容器健康状态外，还要从客户端验证：

- 管理端可登录，已有账号、Groups、Policies、Networks 没有变化。
- 已有 Peer 保持原身份和 NetBird IP。
- Routing Peer 在线，授权资源的真实 TCP/HTTPS 请求可达。
- 非授权账号或设备无法访问同一资源。
- 业务请求前后 Routing Peer 的发送/接收计数增长，证明流量确实经过 NetBird 数据平面。

## 11. 直连端口与 QUIC 不能只改安全组

- Routing Peer 的 WireGuard UDP 端口常见为 `51820`，必须核对实际监听及映射；
  TCP 大端口范围不会放行 UDP。只给需要公网直连的节点增加相应规则。
- UDP 443 必须明确属于 Relay QUIC 还是反向代理 HTTP/3。前者需要 Relay TLS，
  不能只看到宿主机有 UDP 443 就认定已启用。
- 文件证书续期后，确认进程加载了新证书；挂载目录发生更新不等于进程自动重载。
- 实施步骤、证书处理与局部回滚见 [QUIC 运维手册](../operations/relay-quic-runbook.md)。
