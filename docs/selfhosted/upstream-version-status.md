# NetBird 上游版本状态

> 最近核对时间：2026-07-01

## 当前结论

- 官方仓库：`netbirdio/netbird`
- 官方 `releases/latest`：`v0.73.2`
- 最新稳定版本：`v0.73.2`
- 发布时间：2026-06-22
- Release commit：`2ebf260`
- 上游 `main` HEAD：`4ef65294e970b8559cc222c7f184313fae22f272`
- 本仓库主线：继续使用官方 `releases/latest` 安装入口，不固定下载旧版本脚本。

核对来源：

- https://github.com/netbirdio/netbird/releases/latest
- https://github.com/netbirdio/netbird/releases/tag/v0.73.2
- https://github.com/netbirdio/netbird/releases

## 最近版本变化摘要

`v0.73.2` 是当前 GitHub Release API 返回的 `latest` 稳定版本，不是 prerelease。

本次核对时，上游仓库还能看到 `v0.74.0-rc.*` 和 `v0.75.0-rc.*` 预发布标签。它们不是稳定版本，本仓库不把 RC 版本写成默认部署目标。

对自建部署最需要关注的稳定线变化：

- `v0.71` 起支持 IPv6 overlay addressing。新账号默认对 `All` 组启用 IPv6，已有账号需要在 `Settings > Network` 按组开启。
- 本地用户 MFA 已进入主线能力。不接外部 IdP 的部署，建议在首个管理员账号创建后开启 MFA，并保留备用管理员账号。
- Reverse Proxy / BYOP 相关能力持续演进，仍以官方 Dashboard 和官方文档当前可见能力为准。
- K8S 场景建议优先使用 `Networks`、Routing Peer、Network Resources 和 Access Policies；旧的 Network Routes 更适合保留给默认路由、站点互联等明确场景。

## 对本仓库文档的影响

- 新建部署仍优先执行官方 `getting-started.sh` 最新入口。
- 文档中的示例镜像版本可以固定到 `v0.73.2`，但实际生产升级要先在测试环境验证。
- 已有部署从 `v0.71` 或 `v0.72` 升级到 `v0.73` 时，不建议立刻全量启用 IPv6；先选一个测试组，确认客户端版本、路由、DNS、ACL 与 Exit Node 行为都符合预期。
- 如果使用本地用户模式，应在首个管理员账号创建后开启 MFA，并补充备用管理员账号。
- Reverse Proxy / BYOP 相关内容仍以官方文档当前可见能力为准，不在本仓库提前写成强制主线。

## 例行同步步骤

```bash
git pull --ff-only origin main
git ls-remote --tags --sort='v:refname' https://github.com/netbirdio/netbird.git | tail -30
git ls-remote https://github.com/netbirdio/netbird.git HEAD refs/heads/main
curl -s https://api.github.com/repos/netbirdio/netbird/releases/latest | jq -r '.tag_name, .published_at, .html_url, .prerelease'
```
