# CHANGELOG

## Unreleased

- 将多用途 Docker 主机上的 Routing Peer 默认网络从 host 改为独立 bridge，并
  强制校验 Userspace 数据面，避免旧内核 nftables / iptables 冲突影响业务容器
- 增加业务容器 DNS、SNAT、TCP 和重启次数的变更前后回归，以及只停止 Routing
  Peer 的最小化故障隔离步骤
- 明确 `Netstack` 不等于宿主机网络命名空间隔离，公网 IP 可用也不等于 VPN
  数据面可用
- 增加客户端本地 LAN 与远端大网段重叠的最长前缀陷阱，以及 `/32`、传输计数和
  抓包联合验收方法

## 0.3.0 - 2026-08-13

- 新增 Kubernetes 集群内 Routing Peer 生产运维手册，覆盖 Operator / VM / 手工 DaemonSet 选型、双节点独立身份、短期受限 Setup Key、节点标签、持久化和分阶段发布
- 新增 Pod IP、ClusterIP、远端 NodePort、Pod 外联与监控 remote-write 联合回归，明确 DNS 成功不等于 TCP、SNAT 和应用链路正常
- 增加 CentOS 7、旧内核、legacy iptables / nftables 冲突诊断与 `NB_USE_NETSTACK_MODE=true` 兼容路径，并说明吞吐取舍和适用边界
- 增加单节点快速隔离、声明式恢复、首次注册后清理 Secret / Setup Key，以及不重启 CNI、kube-proxy、业务 Pod 的排障原则
- 新增 ADR-003，固定 Kubernetes Routing Peer 的安全选型、分阶段上线、独立身份、监控验证和兼容数据面决策
- 重构 K8S 场景的集群内方案，移除“Deployment 直接扩到 3 副本即生产 HA”的简化表述，改为 Operator 优先和完整运维手册入口
- 扩展监控与 AI agent 操作规范，要求同时验证 NetBird 状态、原有集群网络和业务监控数据面
- 更新 2026-08-13 上游稳定版基线：NetBird `v0.76.3`、Dashboard `v2.90.10`
- 增强文档校验，阻止旧稳定版、旧 Kubernetes 官方路径、真实 Setup Key、明文 Setup Key Secret 和生产 `latest` 镜像回流
- 新增云 VPC 容器化 Routing Peer 实操手册，覆盖独立 Compose、固定镜像、持久身份、Setup Key 清除、旧 Compose v1 重建、双云验收和回滚
- 补充 Setup Key 过期不影响已注册 Peer、用户授权需核对实际设备分组，以及 Routing Peer 自身地址需要独立输入链路策略的说明
- 新增 Legacy 外部 IdP 架构升级、备份校验、分阶段发布和回滚手册
- 新增 VPC `/32` 精确授权、域名资源兜底、策略验收和 WireGuard 共存案例
- 新增 Windows、macOS、Linux 客户端安装、升级与一次性 Setup Key 接入手册
- 明确生产 Compose 镜像固定标签、Routing Peer 独立项目和注册密钥生命周期规范
- 新增 ADR-002，记录固定镜像版本和隔离 Routing Peer 的长期决策
- 将文档校验器改为 Python 实现，并新增 PR / main 自动校验工作流
- 扩写 K8S 场景文档，补充路由节点方案、集群内 Deployment YAML、RBAC YAML、kubeconfig、验证与回滚步骤
- 扩写 OpenVPN 替代、白名单系统、Exit Node / Reverse Proxy、多云互通和进阶最佳实践案例为可执行手册
- 更新 `docs/selfhosted/upstream-version-status.md`，集中说明官方 release、上游 HEAD、RC 标签和 `v0.73` 系列升级注意点
- 增补 Docker Compose 配置修改 SOP，覆盖备份、域名、端口、重启验证和回滚步骤
- 增补运维排障 SOP 与路由节点安全组说明
- 新增 `AGENTS.md`，为后续 AI agent 和维护者提供仓库定位、升级流程、文档规范和校验命令
- 新增维护文档、场景模板与 `scripts/validate-docs.sh`，支持持续升级和文档质量校验
- 新增身份源/MFA、设备姿态、Setup Key 自动化、托管 K8S 云厂商 4 个进阶场景文档
- 新增监控审计、灾备恢复演练、持续演进路线图与 ADR 决策记录
- 美化 README 首页，新增项目徽章、适用人群、项目亮点和搜索关键词
- 移除仓库中的 legacy 配置模板与 legacy 文档入口
- 新增场景化实践手册与运维 Playbook
- 增加安全、贡献与版本维护规范文件
- 调整为“官方脚本生成 + 配置文件二次配置”主线
- 增补服务器端 Docker Compose 配置速查与 K8S 例外场景说明
- 明确不依赖本地定制脚本，默认只变更配置文件参数
- 增补阿里云安全组配置说明与端口用途解释

## 2026-03-24

### Added

- 补充《NetBird 自建部署与实践手册》并重构 `README.md`
- 新增文档目录：
  - `docs/selfhosted/`
  - `docs/cases/`
  - `docs/operations/`
- 新增并落地 6 个场景文档（OpenVPN 替代、白名单接入、K8S 接入、出口与代理、多云互通、官方推荐高级实践）
- 新增仓库治理文档：`SECURITY.md`、`CONTRIBUTING.md`

### Changed

- `部署说明.md` 改为新版优先入口
- 统一文档口径为“官方脚本生成 + Docker Compose 配置文件二次配置”

### Fixed

- 将旧版 README 的过时部署链路与兼容事实明确化，避免直接误导新用户
- 修正文档中对新版生成文件名、安装入口与备份对象的混用问题
- 修正新手用户最容易遗漏的阿里云安全组与端口开放说明
