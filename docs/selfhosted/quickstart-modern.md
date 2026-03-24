# 自建部署：官方推荐路径（getting-started.sh）

> 适用版本：NetBird 官方脚本当前最新版（以当前发布版本为准）

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
- Docker 与 compose 插件可用
- `curl`、`jq`

补充说明：

- 官方 Quickstart 以公网域名为前提
- 如果没有域名，不建议按这套主线部署
- 如果你在中国大陆面向公网使用，建议使用已备案域名

## 3. 部署入口（官方唯一入口）

```bash
export NETBIRD_DOMAIN=netbird.example.com
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh | bash
```

> 我们的策略：本地不维护自定义部署脚本。官方脚本负责“创建/更新模板”，我们只维护“配置文件可读性和配置一致性”。

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

## 7. 参考

- 官方快速开始：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- 外部反向代理接入说明：https://docs.netbird.io/selfhosted/reverse-proxy
- 本地配置说明（官方）：https://docs.netbird.io/selfhosted/configuration-files
