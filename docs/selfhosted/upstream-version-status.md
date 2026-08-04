# NetBird 上游版本状态

> 最近核对时间：2026-08-04

## 当前稳定基线

| 组件 | 稳定版本 | 发布时间 | 核对依据 |
| --- | --- | --- | --- |
| NetBird Server / Client | `v0.76.1` | 2026-07-31 | GitHub `releases/latest`，`prerelease=false` |
| NetBird Dashboard | `v2.90.9` | 2026-08-01 | Dashboard GitHub `releases/latest`，`prerelease=false` |

- NetBird release：https://github.com/netbirdio/netbird/releases/tag/v0.76.1
- Dashboard release：https://github.com/netbirdio/dashboard/releases/tag/v2.90.9
- 核对时 NetBird `main` HEAD：`bc7a15ab71d9e9ed944fa3ec17952e77a696595d`
- 新部署继续使用官方 `releases/latest/download/getting-started.sh` 作为生成配置的入口。
- 生产 Compose 必须把每个镜像固定到已验证标签，不能把 `latest` 当作部署版本。

脚本入口与生产镜像标签解决的是两个不同问题：脚本入口用于获取官方当前安装逻辑；固定标签用于保证重启、扩容和灾备恢复时不会无意升级。

## `v0.74` 到 `v0.76` 的关注点

升级前应阅读跨越版本的完整 release notes。对本仓库场景影响较大的变化包括：

- `v0.74` 增加 Agent Network 等能力，并继续演进连接和路由逻辑。
- `v0.75` 更新桌面客户端界面和配置管理，并增强自建管理及网络能力。Windows 客户端升级后要复核服务、配置目录、Peer 身份和路由。
- `v0.76.0` 是安全相关版本，旧部署不应长期停留在更早版本。
- `v0.76.1` 是当前维护版本，生产升级仍要经过备份、测试、分阶段替换和业务验收。

不要只看服务端容器是否为 `Up`。升级验收至少覆盖管理端登录、Peer 在线、直连/Relay、DNS、Routing Peer、授权资源、非授权资源和真实应用协议。

## 推荐镜像清单

下面是本次实操验证形成的显式标签示例。只选择你当前拓扑实际使用的组件，不要为了“统一”一次性替换身份源、数据库和反向代理：

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
  routing-peer:
    image: netbirdio/netbird:0.76.1
```

Legacy 外部 IdP 部署可能还包含 Caddy、Coturn、PostgreSQL 和 IdP。保留现有账户数据时，应先确认官方迁移工具是否支持当前身份架构；不支持时采用原地分阶段升级，不强行切换部署模型。

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
6. 先升级核心 NetBird 组件，观察日志和业务链路。
7. 更新本页、README、部署说明、客户端和场景案例。
8. 运行 `./scripts/validate-docs.sh` 后再提交。

官方参考：

- https://docs.netbird.io/selfhosted/maintenance/upgrade
- https://docs.netbird.io/selfhosted/maintenance/backup
- https://docs.netbird.io/selfhosted/migration/combined-container
