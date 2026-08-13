# NetBird 上游升级跟踪与兼容维护流程

> 目标：让本仓库能跟随 NetBird 官方版本持续演进，而不是一次性写完就过期。

## 1. 什么时候需要执行

建议在下面几种情况下执行本流程：

- 每月固定例行检查一次。
- NetBird 官方发布新的 stable release。
- 官方文档中 `Networks`、`Routes`、`Reverse Proxy`、`Kubernetes`、`Self-hosted` 等页面有明显变更。
- 用户反馈某个案例配置照抄后不可用。
- 本仓库准备发版本或打 tag 前。

## 2. 核对官方最新版本

在仓库根目录执行：

```bash
git pull --ff-only origin main
curl -s https://api.github.com/repos/netbirdio/netbird/releases/latest | jq -r '.tag_name, .published_at, .html_url, .prerelease'
git ls-remote --tags --sort='v:refname' https://github.com/netbirdio/netbird.git | tail -30
git ls-remote https://github.com/netbirdio/netbird.git HEAD refs/heads/main
```

判断规则：

- `releases/latest` 且 `prerelease=false` 才能写成当前稳定版本。
- `vX.Y.Z-rc.*` 只能写成预发布观察项，不能写成本仓库默认部署目标。
- 官方脚本安装入口继续使用 `releases/latest/download/getting-started.sh`，不要在文档里硬编码旧脚本下载地址。

## 3. 必须同步更新的文件

每次上游 stable 版本变化，至少检查并更新：

| 文件 | 需要检查什么 |
| --- | --- |
| `README.md` | 最近核对时间、最新稳定版、阅读入口 |
| `部署说明.md` | 5 分钟部署说明里的版本状态 |
| `docs/selfhosted/upstream-version-status.md` | release、发布时间、commit、影响摘要 |
| `docs/selfhosted/quickstart-modern.md` | 升级注意点、自建入口是否变化 |
| `docs/selfhosted/docker-compose-config-cheatsheet.md` | 生成文件名、配置文件名、环境变量是否变化 |
| `docs/cases/*.md` | Networks / Routes / Reverse Proxy / K8S 操作路径是否变化 |
| `docs/operations/*.md` | 升级、备份、排障命令是否仍正确 |
| `CHANGELOG.md` | 记录本次文档兼容更新 |

## 4. 官方文档重点页面

优先核对这些页面：

- Self-hosted Quickstart：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- Configuration Files：https://docs.netbird.io/selfhosted/configuration-files
- Routing Peers：https://docs.netbird.io/manage/networks/how-routing-peers-work
- Networks：https://docs.netbird.io/manage/networks
- Network Routes：https://docs.netbird.io/manage/network-routes
- Exit Nodes：https://docs.netbird.io/manage/network-routes/use-cases/exit-nodes
- Access Control：https://docs.netbird.io/manage/access-control/manage-network-access
- Setup Keys：https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
- Reverse Proxy：https://docs.netbird.io/manage/reverse-proxy
- Kubernetes Routing Peers：https://docs.netbird.io/use-cases/kubernetes/routing-peers-and-kubernetes
- Kubernetes Operator：https://docs.netbird.io/manage/integrations/kubernetes

## 5. 兼容性判断口径

更新文档时按这个优先级处理：

1. 官方 stable release 说明。
2. 官方文档当前页面。
3. 官方仓库源码和示例。
4. 本仓库已有实战案例。
5. 经验判断。

如果只能基于经验判断，必须在文档中写明“建议先在测试环境验证”，不要写成确定事实。

## 6. 影响面检查清单

每次 NetBird 升级时，至少检查下面能力是否影响文档：

| 能力 | 检查点 |
| --- | --- |
| Self-hosted | 官方脚本参数、生成文件、默认身份模式、反向代理选项 |
| Dashboard | 菜单路径、字段名称、Networks / Routes 页面是否调整 |
| Client | `netbird up` 参数、环境变量、`netbird status` 输出 |
| Routing Peer | Masquerade、metric、高可用、IP forwarding、local forwarding |
| Access Control | 默认策略、端口策略、posture checks、组同步 |
| DNS | Domain Resource、Local DNS Forwarder、端口变化 |
| Exit Node | Auto Apply、IPv6、DNS 防泄漏、ICMP 策略要求 |
| Reverse Proxy | 服务端前置条件、认证方式、`netbird expose` 参数 |
| Kubernetes | Deployment YAML、Operator CRD、镜像版本、探针命令 |
| Legacy external IdP | 官方迁移工具是否支持当前拓扑、账号映射、数据库备份与恢复 |

生产 Compose 还必须核对：

```bash
docker compose config --images
```

所有运行镜像都应使用明确标签。首次安装脚本使用 `releases/latest` 不影响这一要求。

## 7. 文档更新后的本地校验

执行：

```bash
./scripts/validate-docs.sh
```

如果没有执行权限：

```bash
bash scripts/validate-docs.sh
```

至少确认：

- 本地 Markdown 链接存在。
- 代码围栏成对。
- YAML 代码块可解析。
- 没有旧版本号和旧官方路径残留。
- `git diff --check` 通过。

## 8. PR 描述模板

```markdown
## Summary

- 更新 NetBird 上游版本状态到 `<version>`
- 同步受影响文档：
  - `README.md`
  - `docs/selfhosted/upstream-version-status.md`
  - `docs/cases/...`
- 补充兼容性说明：

## Validation

- `./scripts/validate-docs.sh`
- 官方 latest：`<version>`，`prerelease=false`
- 如有实际部署测试，写明环境和结果
```

## 9. 不应该做的事

- 不要因为看到 RC 标签就把仓库默认版本改成 RC。
- 不要把未验证的 Dashboard 新功能写成生产主线。
- 不要恢复 legacy 配置模板作为默认路径。
- 不要把真实密钥、真实内网拓扑、真实公网 IP 写进文档。
- 不要删除已有案例的“验证、排障、回滚”章节。
