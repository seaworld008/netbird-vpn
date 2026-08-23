# NetBird 上游版本状态

> 最近核对时间：2026-08-23

## 当前稳定基线

| 组件 | 稳定版本 | 发布时间 | 核对依据 |
| --- | --- | --- | --- |
| NetBird Server / Client | `v0.77.1` | 2026-08-21 | GitHub `releases/latest`，`prerelease=false` |
| NetBird Dashboard | `v2.91.1` | 2026-08-14 | Dashboard GitHub `releases/latest`，`prerelease=false` |

- NetBird release：https://github.com/netbirdio/netbird/releases/tag/v0.77.1
- NetBird compare：https://github.com/netbirdio/netbird/compare/v0.77.0...v0.77.1
- Dashboard release：https://github.com/netbirdio/dashboard/releases/tag/v2.91.1
- NetBird `v0.77.1` peeled commit：`79a06720b684768b421f0a54f3bb14f22704994f`
- 核对时 NetBird `main` HEAD：`ee253feddfd08a1b559d4014cbcf8d64cabed937`
- 新部署继续使用官方 `releases/latest/download/getting-started.sh` 作为生成配置的入口。
- 生产 Compose 必须把每个镜像固定到已验证标签，不能把 `latest` 当作部署版本。

本轮已经完成 `v0.77.1` 的官方 release、release assets、脚本头部、官方文档和
Docker OCI manifest 可用性核对。`netbird`、`netbird-server`、`reverse-proxy`、
`management`、`signal`、`relay` 的 `0.77.1` 标签以及 Dashboard `v2.91.1`
均能解析到 Linux 多架构 manifest。Windows MSI 与独立 checksums 资产均存在，
但 MSI 没有列入 checksums 文本；本文的 MSI SHA256 通过 Release API 的 asset
digest 单独核对。

本轮**没有**使用 `v0.77.1` 执行真实服务端、Routing Peer 或客户端升级，因此
不能把下面 `v0.77.0` 的生产验证结论自动继承给补丁版本。生产环境仍要先在隔离
环境验证，再把确认过的标签或 digest 写入 Compose / Kubernetes 清单。

## 已有真实升级证据（`v0.77.0`）

本仓库已完成以下 `v0.77.0` 脱敏生产路径验证：

- Legacy 独立 Management / Signal / Relay 与外部 IdP 拓扑原地升级，Dashboard
  同步升级到 `v2.91.1`，外围 IdP、数据库、Caddy 和 Coturn 保持原版本。
- Standalone Routing Peer 保持原部署模型、身份和资源，只替换固定镜像标签。
- Kubernetes Userspace Routing Peer 先验证单实例，再把双 Peer 按节点逐个升级；
  NetBird IP、身份文件、Pod CIDR、Service CIDR 和真实 TCP 均保持正常。
- 定向公网资源的单副本 Routing Peer 通过授权客户端 `/32` 路由、真实 HTTPS 和
  Peer 传输计数增长验证，同机 Docker WireGuard 未重启。

这表示上述路径对 `v0.77.0` 已有真实升级证据，不表示 `v0.77.1` 或所有 CNI、
内核和身份源组合可以跳过自己的备份与回归。

脚本入口与生产镜像标签解决的是两个不同问题：脚本入口用于获取官方当前安装逻辑；固定标签用于保证重启、扩容和灾备恢复时不会无意升级。

## `v0.74` 到 `v0.77.1` 的关注点

升级前应阅读跨越版本的完整 release notes。对本仓库场景影响较大的变化包括：

- `v0.74` 增加 Agent Network 等能力，并继续演进连接和路由逻辑。
- `v0.75` 更新桌面客户端界面和配置管理，并增强自建管理及网络能力。Windows 客户端升级后要复核服务、配置目录、Peer 身份和路由。
- `v0.76.0` 是安全相关版本，旧部署不应长期停留在更早版本。
- `v0.76.3` 包含连接唤醒、用户变更影响范围和 Reverse Proxy 授权等补丁。
- `v0.77.0` 继续演进 Agent Network、客户端路由、IPv6 转发和
  调试信息匿名化。Routing Peer、Domain Resource、其他 WireGuard VPN 和旧内核
  环境升级后必须重做真实数据面回归。
- `v0.77.1` 是当前稳定补丁版，release notes 未列出独立的 breaking change 或
  迁移章节。它为 `getting-started.sh` 增加环境变量驱动的无交互新装，修复
  Windows 路由排序、NRPT 清理和静默升级，并增强 Android SSH、网络切换与
  Posture 网络地址上报。
- Management 现在明确拒绝 One-off Setup Key 的 `usage_limit > 1`；需要多次
  注册时必须使用 Reusable Key。Policy API 的 `ports` 与 `port_ranges` 互斥，
  同一规则混合单端口和范围时，应全部用 range 表示。
- Dashboard `v2.91.1` 修复版本构建信息识别；前端升级后仍要核对显示版本与实际
  镜像标签一致。

生产升级仍要经过备份、测试、分阶段替换和业务验收。

不要只看服务端容器是否为 `Up`。升级验收至少覆盖管理端登录、Peer 在线、直连/Relay、DNS、Routing Peer、授权资源、非授权资源和真实应用协议。

启用 NetBird Reverse Proxy 时，还要让 Management 与 Proxy 同步升级。官方说明
指出：从 `v0.76.1` 起，如果 Proxy 比 Management 新，Agent Network LLM cost
metering 会被静默停用并只留下 warning。升级前后应比较 Proxy 的实际版本与
`GET /api/instance/version` 返回的 `management_current_version`。

## 推荐镜像清单

新安装以官方 Quickstart 生成的 combined server 拓扑为准：Management、Signal、
Relay 和 STUN 集中在 `netbird-server`。下面只展示当前稳定候选标签，不是完整
Compose，也不替代环境级验证：

```yaml
services:
  dashboard:
    image: netbirdio/dashboard:v2.91.1
  netbird-server:
    image: netbirdio/netbird-server:0.77.1
  routing-peer:
    image: netbirdio/netbird:0.77.1
```

Legacy 多容器部署仍可能使用独立 `management`、`signal`、`relay`，并包含
Caddy、Coturn、PostgreSQL 和外部 IdP。只在确认当前环境就是该拓扑后更新这些
独立镜像，不能拿 Legacy 清单新建环境。保留现有账户数据时，应先确认官方迁移
工具是否支持当前身份架构；不支持时采用原地分阶段升级，不强行切换部署模型。

## 每月核对命令

```bash
curl -fsSL https://api.github.com/repos/netbirdio/netbird/releases/latest \
  | jq -r '.tag_name, .published_at, .html_url, .prerelease'
curl -fsSL https://api.github.com/repos/netbirdio/dashboard/releases/latest \
  | jq -r '.tag_name, .published_at, .html_url, .prerelease'
git ls-remote https://github.com/netbirdio/netbird.git HEAD refs/heads/main
```

只有 `prerelease=false` 的 GitHub latest release 才能成为仓库默认基线。RC、nightly 和 `main` HEAD 只作为兼容观察项。

## 版本更新清单

1. 阅读 NetBird 和 Dashboard 跨版本 release notes。
2. 核对官方升级、备份和部署模型迁移文档。
3. 在隔离环境渲染 Compose：`docker compose config`。
4. 确认 `docker compose config --images` 没有漂移标签。
5. 备份配置、数据库和身份源数据，并校验备份可读性。
6. 启用 Reverse Proxy 时，比较 Proxy 实际版本与 Management 当前版本。
7. 先升级核心 NetBird 组件，观察日志和业务链路。
8. 更新本页、README、部署说明、客户端和场景案例。
9. 运行 `./scripts/validate-docs.sh` 后再提交。

官方参考：

- https://docs.netbird.io/selfhosted/maintenance/upgrade
- https://docs.netbird.io/selfhosted/maintenance/backup
- https://docs.netbird.io/selfhosted/migration/combined-container
