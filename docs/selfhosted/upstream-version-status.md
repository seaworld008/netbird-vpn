# NetBird 上游版本状态

> 最近核对时间：2026-09-18。发布时间按上游 UTC 日期记录。

## 当前稳定基线

| 组件 | 稳定版本 | 发布时间 | 核对依据 |
| --- | --- | --- | --- |
| NetBird Server / Client | `v0.78.2` | 2026-09-14 | GitHub `releases/latest`，`prerelease=false` |
| NetBird Dashboard | `v2.92.0` | 2026-09-03 | Dashboard GitHub `releases/latest`，`prerelease=false` |

- [NetBird v0.78.2 release](https://github.com/netbirdio/netbird/releases/tag/v0.78.2)（当前稳定版本，已完成存量生产升级验收）
- [跨版本变更](https://github.com/netbirdio/netbird/compare/v0.78.1...v0.78.2)
- [Dashboard release](https://github.com/netbirdio/dashboard/releases/tag/v2.92.0)
- NetBird `v0.78.1` peeled commit：`23a1487c26c5f00353c046bc818069189650dbfb`
- 核对时 `main` HEAD：`9615d2ab162e7badee5c8b4e84048ce49e1db6e7`，仅为观察值，不作为部署目标。
- 首次安装继续用官方 `releases/latest/download/getting-started.sh`，生成后固定镜像。
- 存量外部 IdP 不强行迁移到组合容器，按现有拓扑分阶段升级。

## 本轮制品核对

官方 Release API 的 `getting-started.sh` digest 与实际下载SHA256一致：

```text
a8d17cdb2229c680514063a6893d117aad55343d8dd2c703d1aa1033577b1570
```

Windows amd64 MSI 的官方 asset digest 为：

```text
91fdc2bc4ecd45e0a3773ac06587edb023d64f138dadcc1bb672d14de842cbc5
```

本轮没有安装MSI；发放客户端时仍需对实际下载文件做SHA256和签名校验。
不要把不含该MSI条目的checksums文本当作已校验安装包。

已在实际 Linux amd64 主机拉取并记录以下官方镜像：

| 镜像 | 官方 RepoDigest 的 SHA256 |
| --- | --- |
| `netbirdio/management:0.78.2` | `66a008a3a865cd5ed3f79261bf97b67e7b9be6462ee190d33a9a9eaca3924fad` |
| `netbirdio/signal:0.78.2` | `8b06ac050d87e7e2f782e806e2adb8b58bbc17d484c590cb111cedeaa0b9d634` |
| `netbirdio/relay:0.78.2` | `a845ba99641778b8e58df5abe5871ad374573f8b51c504691a5d7f406f477e93` |
| `netbirdio/netbird:0.78.2` | `0d6653f21f0417b6014e4c621c75e898e06698e1cce973398d1c3c45a30f6bd6` |
| `netbirdio/dashboard:v2.92.0` | `fa2d8b02a81761e4d2a22df4041d13316b7635f1e93273eafeb53d4991e55b5a` |

另通过官方 OCI Registry 核对组合容器与 Proxy 的 `0.78.2` manifest，均包含
Linux amd64/arm64/arm；这是制品可用性检查，不是现场部署验收：

| 镜像 | manifest SHA256 |
| --- | --- |
| `netbirdio/netbird-server:0.78.2` | 待组合容器实测 |
| `netbirdio/reverse-proxy:0.78.2` | 待组合容器实测 |

部分节点无法直连镜像仓库时，导入已校验归档，导入后的客户端image ID与可信
下载主机一致。固定官方标签与 `IfNotPresent` 允许现有节点复用缓存；新增或
重建节点仍需预置镜像，或使用有授权的镜像仓库。归档不能替代新节点准备。

## 本轮真实部署与验收

- 外部IdP存量部署：Management/Signal/Relay 已升级到 `0.78.2`，Routing Peer
  同步到 `0.78.2`，Dashboard 保持 `v2.92.0`；配置、SQLite在线备份、完整性与
  对象数量已核验，身份源数据库已备份。Zitadel/PostgreSQL 保持现状，Coturn
  已升级到官方最新稳定 `4.18.0-r0`，Caddy `2.11.4` 保持现状。
- Relay 所在宿主机持久化 `net.core.rmem_max=7500000` 和
  `net.core.wmem_max=7500000`，重启 Relay 后 quic-go 的 UDP 缓冲区告警消失。
  该参数按官方 quic-go 建议设置，并保留升级前 sysctl 备份。
- 在新控制面回滚点之上单独启用Relay QUIC；Caddy的UDP443移交同一Relay，
  保留TCP443 WebSocket。独立客户端显示 `via quic`，WS升级握手返回101。
- 文件证书的宿主机检查任务已部署，指纹相同不重启；域名错误拒绝重载，模拟
  更新只作用于指定Relay并在指纹验证后记录状态。自然ACME续期仍需后续监控。
- 两台Standalone、两个Kubernetes路由节点和一个定向出口共五个在用Peer逐个
  升级，保持IP、公钥身份、FQDN、资源与原有Kernel/Userspace模式。
- Kubernetes单节点后再双节点验证Pod IP、ClusterIP、远端NodePort、Pod外联；
  监控发送计数增长、错误计数未增加、队列为零。普通业务Pod重启次数保持；
  一项原本已完成的观察Job在窗口内被正常清理。
- 控制入口、原路由及业务应用协议完成回归。测试客户端的业务路径为P2P；
  未把QUIC Available或WS101写成强制中继的完整性能测试。
- 升级后两个来源各六分钟探测，加本机经VPN到私网MQ的补充测试，共811项
  测量结果、0失败。本机Redis常规36/36、额外15条并发成功，两条长连接PING
  最大约11.6ms；这些是此次有限窗口的证据，不是长期稳定性保证。

组合 `netbird-server` 新装、Reverse Proxy、Windows/MSI安装和所有平台组合没有
在本轮执行部署。不要把上面的存量路径结果扩展成所有场景均已验证。

详细步骤见 [QUIC手册](../operations/relay-quic-runbook.md)、
[间歇超时排查](../operations/remote-development-timeouts.md) 和
[Kubernetes路由手册](../operations/kubernetes-routing-peer-runbook.md)。

## 跨版本注意点

升级前阅读完整release notes，重点包括：

- `v0.78.1` 修复SQLite网络映射对按Peer指定Routing Peer的Networks的处理。
  所以上线后必须核对原资源、来源策略和实际数据面，不能只看容器Up。
- `v0.78.0` 调整lazy connection、统一ACL过滤，修复ICEBind竞争、握手监听
  时序和网络丢失后的连接清理；Relay/客户端使用更新的Go/QUIC依赖。这些变更
  值得回归，不等于已证明它们能修复某一条现场线路的丢包。
- 远程debug jobs需要管理员明确opt-in；不要因升级后不可用就自动开启远程作业
  或上传诊断包。
- Windows DNS/NRPT行为变化，升级Windows客户端须重新检查DNS、路由和其他VPN。
- 启用Reverse Proxy时，仍要同步核对Management/Proxy兼容版本和Rosenpass变化。
- One-off使用次数、Policy `ports`/`port_ranges`互斥等既有约束继续适用。

官方新装脚本支持环境变量输入，并有 `use-ip` HTTP模式；本手册生产主线仍采用
真实域名+HTTPS。官方占位域名 `netbird.example.com` 会被拒绝，复制后须替换。
不要把新装脚本当作现有Compose的无损升级器。

## 当前标签示例

新装按官方生成结果确认组合服务端及Proxy；下面只是固定标签示例：

```yaml
services:
  dashboard:
    image: netbirdio/dashboard:v2.92.0
  netbird-server:
    image: netbirdio/netbird-server:0.78.2
  routing-peer:
    image: netbirdio/netbird:0.78.2
```

目标平台的manifest、配置与兼容性检查方法见
[上游维护流程](../maintenance/upstream-upgrade-workflow.md)。

## 后续核对

```bash
curl -fsSL https://api.github.com/repos/netbirdio/netbird/releases/latest \
  | jq -r '.tag_name, .published_at, .html_url, .prerelease'
curl -fsSL https://api.github.com/repos/netbirdio/dashboard/releases/latest \
  | jq -r '.tag_name, .published_at, .html_url, .prerelease'
git ls-remote https://github.com/netbirdio/netbird.git HEAD refs/heads/main
```

只有各仓库 `releases/latest` 且 `prerelease=false` 才是稳定基线。Git远端查询
失败时可用官方GitHub Git refs API核对，并记录替代路径；不能拿旧缓存当作新证据。

历史版本和已经完成的旧实测保留在 [CHANGELOG](../../CHANGELOG.md) 与
[存量外部IdP升级手册](../operations/legacy-external-idp-upgrade.md)，不机械替换
历史版本号。
