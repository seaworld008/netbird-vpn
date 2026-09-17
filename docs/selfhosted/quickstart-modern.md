# 自建部署：官方推荐路径（getting-started.sh）

> 适用版本：NetBird 官方脚本当前最新版。最近核对时间为 2026-09-18，官方最新稳定版为 NetBird `v0.78.2`、Dashboard `v2.92.0`。

## 0. 核心约束（先确认）

- 服务器端统一采用 **Docker Compose**。你们不改造脚本，仅依赖官方脚本生成初始文件，再改配置文件。
- 需要 IdP/用户体系按需求再决定，默认优先本地用户。

## 1. 部署目标

- 新建一套可稳定对外提供访问的 NetBird 服务。
- 默认支持内置用户模型，减少额外 IdP 依赖。
- 提供统一出口（Dashboard/API/Client）访问链路。

## 2. 前置要求

- Linux VPS（公有云/自有机房都可）
- 公网域名，且已解析到服务器公网 IP
- 端口 `80/tcp`、`443/tcp`、`3478/udp` 可被公网访问
- 公网 Routing Peer 的实际 WireGuard UDP 端口（常见 `51820`）已单独核对；
  控制面主机没有运行 Peer 时不需要为此一律开放该端口
- 如需 QUIC，确认 UDP 入口确实到达 Relay，而非反向代理的 HTTP/3，见
  [QUIC 运维手册](../operations/relay-quic-runbook.md)
- Docker 与 compose 插件可用
- `curl`、`jq`

补充说明：

- 官方 Quickstart 以公网域名为前提
- 如果没有域名，不建议按这套主线部署
- 如果你在中国大陆面向公网使用，建议使用已备案域名

## 3. 部署入口（官方唯一入口）

交互式首次安装：

`netbird.example.com` 是文档占位符，`v0.77.1` 脚本会拒绝原样值。执行前必须
替换为已解析到服务器的真实 FQDN。

```bash
export NETBIRD_DOMAIN=netbird.example.com
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh | bash
```

> 我们的策略：本地不维护自定义部署脚本。官方脚本负责“创建/更新模板”，我们只维护“配置文件可读性和配置一致性”。

脚本会要求选择反向代理。当前官方选项为内置 Traefik、现有 Traefik、Nginx、
Nginx Proxy Manager、外部 Caddy 和其他手工代理；内置 Traefik 是默认项。随后
还可能询问是否启用 NetBird Proxy 与 CrowdSec。不要在不了解公网暴露范围时直接
启用可选代理服务。

### 3.1 `v0.77.1` 无交互新装

`v0.77.1` 起，官方脚本可以从环境变量读取所有提示项，适合 cloud-init、CI 或
Terraform `remote-exec`。这是“全新安装或重新生成配置”的入口，不是现有生产
环境的升级命令。运行前必须把示例域名和邮箱换成自己的值：

```bash
set -euo pipefail

INSTALLER="$(mktemp)"
cleanup_installer() {
  rm -f "$INSTALLER"
}
trap cleanup_installer EXIT HUP INT TERM

curl -fsSL \
  https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh \
  --output "$INSTALLER"
chmod 700 "$INSTALLER"

NETBIRD_DOMAIN=vpn.example.com \
NETBIRD_LETSENCRYPT_EMAIL=ops@example.com \
NETBIRD_REVERSE_PROXY_TYPE=0 \
NETBIRD_ENABLE_PROXY=false \
NETBIRD_ENABLE_CROWDSEC=false \
NETBIRD_NON_INTERACTIVE=true \
  bash "$INSTALLER"
```

关键变量：

| 变量 | 无交互要求或默认值 |
| --- | --- |
| `NETBIRD_DOMAIN` | 必填，必须是已解析到服务器的真实 FQDN |
| `NETBIRD_LETSENCRYPT_EMAIL` | 使用内置 Traefik 时必填 |
| `NETBIRD_REVERSE_PROXY_TYPE` | 默认 `0`，即内置 Traefik |
| `NETBIRD_ENABLE_PROXY` | 默认 `false` |
| `NETBIRD_ENABLE_CROWDSEC` | 默认 `false` |
| `NETBIRD_BIND_LOCALHOST_ONLY` | 外部代理类型默认 `true` |
| `NETBIRD_NON_INTERACTIVE` | 设为 `true` 后即使存在 TTY 也不提示 |

布尔变量必须写成字面量 `true` 或 `false`。必填变量缺失时脚本应明确退出，不应
通过补空值继续。自动化系统仍要保存脚本来源、生成文件差异和镜像清单，不要把
“无交互”误解为“无需审查”。

脚本执行后请按 [docker-compose-config-cheatsheet](./docker-compose-config-cheatsheet.md) 做二次配置。

## 4. 首次登录

- Dashboard：`https://netbird.example.com`
- 新版官方主线默认不会在终端输出管理员密码
- 首次访问时会进入 `/setup`
- 在 `/setup` 页面创建第一个管理员账号和密码

## 5. 服务器端只改配置的三步

1. 先确认生成文件
   - `docker-compose.yml`
   - `config.yaml`
   - `dashboard.env`
   - `proxy.env`（仅在启用 NetBird Proxy 时）
   - `caddyfile-netbird.txt` / `nginx-netbird.conf` / `npm-advanced-config.txt`（按反向代理选项生成）

2. 只修改必要字段
   - `NETBIRD_DOMAIN`
   - `config.yaml` 中的监听、STUN、外部服务和存储设置
   - 反向代理入口与证书
   - 管理白名单策略

3. 重启验证

```bash
docker compose pull
docker compose up -d
```

## 6. 与旧模板的关系

本仓库已经移除了 legacy 配置模板。

当前原则是：

- 新建环境完全以官方脚本生成结果为准
- 本仓库只负责解释这些配置文件如何修改和如何用于实际场景

## 7. 当前主线与升级注意点

- `v0.71` 开始支持 IPv6 overlay addressing。升级到 `v0.73` 时，如果是存量环境，仍建议先选测试组启用 IPv6，确认 DNS、ACL、路由、Exit Node 和客户端版本后再扩大范围。
- 不接外部 IdP、使用本地用户的部署，建议在首个管理员账号创建后开启 MFA，并保留备用管理员账号。
- `v0.78.2` 是当前 `releases/latest` 指向的稳定版本；生产环境必须固定镜像标签，并先在测试环境验证后再更新。
- `v0.77.1` 的无交互变量只改变安装输入方式，不会把现有 Compose 自动安全升级到新版本。
- Reverse Proxy、NetBird Proxy 与 CrowdSec 按官方脚本生成结果和当前 Dashboard
  配置；启用前先定义公网暴露、证书、来源地址和回滚边界。

详细版本核对记录见 [NetBird 上游版本状态](./upstream-version-status.md)。

## 8. 参考

- 官方快速开始：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- 外部反向代理接入说明：https://docs.netbird.io/selfhosted/external-reverse-proxy
- 本地配置说明（官方）：https://docs.netbird.io/selfhosted/maintenance/configuration-files
- 官方升级说明：https://docs.netbird.io/selfhosted/maintenance/upgrade
