# docs 目录说明

本目录是 NetBird 仓库的结构化实践手册，按用途分层：

- `selfhosted/`
  - `quickstart-modern.md`：官方推荐安装入口
  - `upstream-version-status.md`：NetBird 官方最新版本核对记录
  - `docker-compose-config-cheatsheet.md`：配置速查（不改脚本）

- `cases/`
  - `01-openvpn-replacement.md`：OpenVPN 替代，含路由节点、资源、策略、验证和回滚
  - `02-whitelisted-system-access.md`：企业内部白名单系统接入，含单资源单组、后端白名单、授权/非授权验证
  - `03-kubernetes-connectivity.md`：K8S 网络打通、完整 YAML、验证与回滚
  - `04-exit-node-and-proxy.md`：Exit Node、Reverse Proxy、`netbird expose` 临时发布
  - `05-multi-cloud-connectivity.md`：阿里云 / 华为云 / AWS / GCP / Azure 多云互通、云防火墙、分阶段验证
  - `06-official-advanced-scenarios.md`：进阶最佳实践，含策略模型、域名资源、Setup Key、高可用和审计模板
  - `07-identity-provider-and-mfa.md`：本地用户、外部 IdP、MFA、组同步、离职回收
  - `08-device-posture-and-zero-trust.md`：Posture Checks、客户端版本、系统、网络范围、进程检查
  - `09-automation-with-setup-keys.md`：Cloud-init、Ansible、Terraform、CI Runner 自动接入
  - `10-managed-kubernetes-clouds.md`：ACK、EKS、GKE、AKS 托管 K8S 差异和检查点
  - `11-precision-vpc-access.md`：按 `/32` 精确授权 VPC 主机、域名资源兜底、验收和 WireGuard 共存
  - `12-client-platform-onboarding.md`：Windows、macOS、Linux 安装升级和一次性 Setup Key 接入
  - `18-kubernetes-targeted-public-egress.md`：Kubernetes 指定节点定向代理公网 IP / 域名、固定白名单出口和同机 WireGuard 无回归验收

- `operations/`
  - `containerized-routing-peer-runbook.md`：云 VPC 容器化 Routing Peer、持久身份、Setup Key 清除、双云验收和回滚
  - `kubernetes-routing-peer-runbook.md`：集群内 Routing Peer、双节点身份、分阶段上线、Netstack 兼容、监控验证和局部隔离
  - `firewall-and-hardening.md`：阿里云安全组、端口与安全加固
  - `operations-playbook.md`：日常运维、备份、升级、回滚与排障 SOP
  - `monitoring-and-audit.md`：服务端、路由节点、客户端巡检、审计与告警建议
  - `disaster-recovery-drill.md`：备份恢复演练、跨主机恢复、DNS 切换和 RPO/RTO
  - `legacy-external-idp-upgrade.md`：外部 IdP 老架构的备份、分阶段升级、验收和回滚

- `maintenance/`
  - `upstream-upgrade-workflow.md`：跟踪 NetBird 官方升级、评估影响、同步文档的标准流程
  - `documentation-governance.md`：文档分层、质量标准、完成定义和审查重点
  - `roadmap.md`：持续演进路线图、维护节奏、backlog 和升级观察点

- `decisions/`
  - `ADR-001-documentation-operating-model.md`：文档运营模型的长期决策记录
  - `ADR-002-pinned-images-and-routing-peer-isolation.md`：固定镜像版本与隔离 Routing Peer 的长期决策
  - `ADR-003-kubernetes-routing-peer-safety-model.md`：Kubernetes Routing Peer 的选型、发布、验证和兼容数据面决策
  - `ADR-004-targeted-public-egress-routing-peer-isolation.md`：定向公网出口的精确资源、单节点固定出口和 Routing Peer 隔离决策

- `templates/`
  - `case-template.md`：新增场景文档时使用的标准模板

建议按以下顺序阅读：

1. `selfhosted/quickstart-modern.md`
2. `selfhosted/upstream-version-status.md`
3. `selfhosted/docker-compose-config-cheatsheet.md`
4. `cases/*`（按业务场景）
5. `operations/*`
6. `maintenance/*`
