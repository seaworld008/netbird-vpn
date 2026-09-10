# 场景路由

只读取当前任务所需的文档，避免把无关案例全部装入上下文。以下链接在本仓库内可直接访问；技能被单独复制时，可从 <https://github.com/SeaWorld008/netbird-vpn> 获取同名文档，并以当前稳定版本和官方文档重新核对易漂移行为。

## 部署和控制面

| 用户目标 | 必读 | 补充 |
| --- | --- | --- |
| 新建自托管 NetBird | [现代 Quickstart](../../../../docs/selfhosted/quickstart-modern.md) | [配置速查](../../../../docs/selfhosted/docker-compose-config-cheatsheet.md)、[防火墙](../../../../docs/operations/firewall-and-hardening.md) |
| 修改 Compose 域名、端口、镜像 | [配置速查](../../../../docs/selfhosted/docker-compose-config-cheatsheet.md) | [运维 Playbook](../../../../docs/operations/operations-playbook.md) |
| 升级现代部署 | [上游版本状态](../../../../docs/selfhosted/upstream-version-status.md)、[升级流程](../../../../docs/maintenance/upstream-upgrade-workflow.md) | [灾备演练](../../../../docs/operations/disaster-recovery-drill.md) |
| 升级 Legacy 外部 IdP | [Legacy 升级 Runbook](../../../../docs/operations/legacy-external-idp-upgrade.md) | [ADR-002](../../../../docs/decisions/ADR-002-pinned-images-and-routing-peer-isolation.md) |
| Relay QUIC、WS、证书续期 | [QUIC Runbook](../../../../docs/operations/relay-quic-runbook.md) | [证书重载](../../../../docs/operations/relay-certificate-refresh.md)、[端口边界](../../../../docs/operations/firewall-and-hardening.md) |
| Redis/MQ/Nacos 等间歇超时 | [分层排障](../../../../docs/operations/remote-development-timeouts.md) | TCP/应用响应分离、命名空间计数、定向包头与多来源对照 |

稳定版本必须在执行时查询 GitHub `releases/latest`，并确认 `prerelease=false`；RC 只观察。服务端主线始终是官方 `getting-started.sh` 生成结果 + Docker Compose，不自行维护替代安装脚本。

## 网络和访问场景

若用户要求直接在已登录的 NetBird 控制台配置，先读 [Chrome 控制台操作](dashboard-chrome-operations.md)，然后再读取对应业务案例。

| 需求关键词 | 主案例 | 关键选择 |
| --- | --- | --- |
| 替代 OpenVPN、员工访问办公室 | [案例 01](../../../../docs/cases/01-openvpn-replacement.md) | 按系统拆资源和权限，不放整个大网段 |
| 白名单后台、财务、审计、最小权限 | [案例 02](../../../../docs/cases/02-whitelisted-system-access.md) | `/32` / Domain、真实端口、后端白名单 |
| 本地访问 K8S API / Pod / Service | [案例 03](../../../../docs/cases/03-kubernetes-connectivity.md) | VM / Operator / 手工 Peer 先选型 |
| 全局固定公网出口、Exit Node | [案例 04](../../../../docs/cases/04-exit-node-and-proxy.md) | 只有明确全局需求才下发默认路由 |
| Reverse Proxy、`netbird expose` | [案例 04](../../../../docs/cases/04-exit-node-and-proxy.md) | 区分改变客户端出口和发布单个服务 |
| 阿里云、华为云、AWS、GCP、Azure | [案例 05](../../../../docs/cases/05-multi-cloud-connectivity.md) | 每云独立 Peer / Network，先查 CIDR 重叠 |
| 高可用、DNS、策略、审计综合实践 | [案例 06](../../../../docs/cases/06-official-advanced-scenarios.md) | 按具体小节加载，不作为宽权限模板 |
| IdP、MFA、入离职、组同步 | [案例 07](../../../../docs/cases/07-identity-provider-and-mfa.md) | 人员身份与设备注册分离 |
| Posture、受管设备、EDR | [案例 08](../../../../docs/cases/08-device-posture-and-zero-trust.md) | 先测试组，验证客户端能回报条件 |
| Cloud-init、Ansible、Terraform、CI | [案例 09](../../../../docs/cases/09-automation-with-setup-keys.md) | Key 短期、限次数、Secret 注入和撤销 |
| ACK、EKS、GKE、AKS | [案例 10](../../../../docs/cases/10-managed-kubernetes-clouds.md) | 同时核对云路由、安全组和 CNI 差异 |
| 精确 VPC `/32`、域名、其他 VPN 共存 | [案例 11](../../../../docs/cases/11-precision-vpc-access.md) | 最长前缀、实际路由和计数验证 |
| Windows / macOS / Linux 客户端 | [案例 12](../../../../docs/cases/12-client-platform-onboarding.md) | 每机身份、平台服务状态、版本和路由 |
| 指定公网 IP / 域名走固定 K8S 出口 | [案例 18](../../../../docs/cases/18-kubernetes-targeted-public-egress.md) | 精确资源、单副本、无默认路由、来源 IP |

## Routing Peer 强制路由

### Standalone 容器

任务涉及多用途 Docker 主机、VPC 容器化 Peer、Userspace 或同机业务时，必须同时读：

- [容器化 Routing Peer Runbook](../../../../docs/operations/containerized-routing-peer-runbook.md)
- [ADR-002](../../../../docs/decisions/ADR-002-pinned-images-and-routing-peer-isolation.md)

默认独立 bridge + `NB_USE_NETSTACK_MODE=true`。上线前后从业务容器内部验证 DNS、真实 TCP、`StartedAt` 和 `RestartCount`；故障先只停止 Routing Peer。

### Kubernetes

任务涉及集群内 Routing Peer 时，必须同时读：

- [Kubernetes Routing Peer Runbook](../../../../docs/operations/kubernetes-routing-peer-runbook.md)
- [ADR-003](../../../../docs/decisions/ADR-003-kubernetes-routing-peer-safety-model.md)

若是定向公网出口，再读：

- [案例 18](../../../../docs/cases/18-kubernetes-targeted-public-egress.md)
- [ADR-004](../../../../docs/decisions/ADR-004-targeted-public-egress-routing-peer-isolation.md)

先记录节点、Pod / Service CIDR、CNI、kube-proxy、netfilter 和业务监控基线；手工方案先单 Peer，第二 Peer 使用独立身份。故障不先重启 CNI、kube-proxy 或业务 Pod。

## 审计、排障和回滚

| 任务 | 必读 |
| --- | --- |
| 日常故障、网络资源不通、Exit Node | [运维 Playbook](../../../../docs/operations/operations-playbook.md) |
| 监控、Activity、巡检、告警 | [监控与审计](../../../../docs/operations/monitoring-and-audit.md) |
| 备份恢复、跨主机演练 | [灾备演练](../../../../docs/operations/disaster-recovery-drill.md) |
| 新增案例或维护技能 | [文档治理](../../../../docs/maintenance/documentation-governance.md)、[ADR-005](../../../../docs/decisions/ADR-005-agent-assisted-netbird-automation.md) |

排障时先分层：控制面、Peer 隧道、资源分发、客户端路由、Routing Peer 到目标、DNS、SNAT / 回程、目标服务。应用 500、数据库列缺失、缓存包装错误等需要沿真实错误归属排查，不因请求经过 NetBird 就默认归因网络。
