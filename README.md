# NetBird 自建部署与实践手册

[![NetBird](https://img.shields.io/badge/NetBird-v0.73.2-00A3FF?logo=wireguard&logoColor=white)](https://github.com/netbirdio/netbird/releases/tag/v0.73.2)
[![中文文档](https://img.shields.io/badge/docs-%E4%B8%AD%E6%96%87%E5%AE%9E%E8%B7%B5%E6%89%8B%E5%86%8C-brightgreen)](docs/README.md)
[![Self Hosted](https://img.shields.io/badge/self--hosted-Docker%20Compose-2496ED?logo=docker&logoColor=white)](docs/selfhosted/quickstart-modern.md)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-ready-326CE5?logo=kubernetes&logoColor=white)](docs/cases/03-kubernetes-connectivity.md)
[![Zero Trust](https://img.shields.io/badge/Zero%20Trust-access%20control-7C3AED)](docs/cases/08-device-posture-and-zero-trust.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-FF69B4)](CONTRIBUTING.md)

> NetBird self-hosted VPN / Zero Trust / WireGuard / Kubernetes / Docker Compose 中文实践手册。

这个仓库面向想要自建、学习和落地 NetBird 的团队和个人，目标是做成一份“入门 + 进阶 + 实战”的用户手册。它重点解决三件事：

- 如何按官方脚本快速完成部署
- 如何在 `docker-compose` 场景下理解和修改配置
- 如何把 NetBird 用到真实业务场景里，而不是只停留在“安装成功”

在 AI 时代，越来越多的多 Agent 系统、自动化任务和开发工具，需要稳定、安全、可审计地访问内网资源、测试环境、K8S 集群和多云网络。这个仓库想做的，就是把这条网络接入链路讲清楚、落到实处，让 NetBird 不只是“能装起来”，而是真的能支撑 AI 时代的协作和自动化需求。

本仓库的定位很明确：

- 服务端以官方脚本生成结果为准
- 服务端部署方式统一按 `docker-compose`
- 文档重点放在“配置说明 + 场景落地 + 运维说明”
- 场景文档按“原理、配置、验证、排障、回滚、扩展”组织，尽量让新手复制示例后能跑通
- 最近一次上游版本核对：2026-07-01，官方最新稳定版为 `v0.73.2`

## 适合谁

- 想自建 NetBird VPN / Zero Trust 网络的新手。
- 正在从 OpenVPN、传统堡垒机或固定 IP 白名单迁移的团队。
- 需要安全访问 K8S、数据库、内网后台、多云 VPC 的 DevOps / SRE。
- 想让 AI Agent、CI Runner、自动化任务安全访问内网资源的工程团队。
- 想持续跟进 NetBird 官方升级、维护中文实践文档的贡献者。

## 项目亮点

- 中文优先，面向新手，步骤尽量可复制。
- 以官方脚本和 Docker Compose 为自建主线，不维护魔改安装器。
- 覆盖 OpenVPN 替代、白名单系统、K8S、多云、Exit Node、Reverse Proxy、IdP、MFA、Posture Checks、Setup Keys。
- 每个核心场景都尽量包含验证、排障和回滚，避免“装完但不会用”。
- 内置 `AGENTS.md`、路线图、ADR 和校验脚本，方便后续 AI agent 持续维护。

## 一、推荐阅读顺序

如果你是第一次打开这个仓库，建议直接从这里开始：

### 部署

- [官方部署说明（新手优先）](docs/selfhosted/quickstart-modern.md)
- [NetBird 上游版本状态](docs/selfhosted/upstream-version-status.md)
- [服务器端配置速查](docs/selfhosted/docker-compose-config-cheatsheet.md)

### 场景案例

- [案例 1：用 NetBird 替代 OpenVPN](docs/cases/01-openvpn-replacement.md)：远程办公接入企业内网
- [案例 2：企业内网白名单系统接入](docs/cases/02-whitelisted-system-access.md)：敏感后台最小权限访问
- [案例 3：本地办公打通云上 K8S 集群网络](docs/cases/03-kubernetes-connectivity.md)：API Server、Pod、Service 网络
- [案例 4：统一出口与代理发布入口](docs/cases/04-exit-node-and-proxy.md)：Exit Node、Reverse Proxy、临时 expose
- [案例 5：打通多云内网](docs/cases/05-multi-cloud-connectivity.md)：AWS / GCP / Azure 互通
- [案例 6：NetBird 进阶最佳实践手册](docs/cases/06-official-advanced-scenarios.md)：策略、域名、Setup Key、高可用、审计
- [案例 7：身份源、用户生命周期与 MFA](docs/cases/07-identity-provider-and-mfa.md)：本地用户、企业 IdP、组同步、离职回收
- [案例 8：设备姿态检查与 Zero Trust](docs/cases/08-device-posture-and-zero-trust.md)：客户端版本、系统、网络、进程检查
- [案例 9：Setup Key 自动化接入](docs/cases/09-automation-with-setup-keys.md)：Cloud-init、Ansible、Terraform、CI Runner
- [案例 10：托管 K8S 云厂商专项](docs/cases/10-managed-kubernetes-clouds.md)：ACK、EKS、GKE、AKS 落地差异

### 运维

- [阿里云安全组与端口说明](docs/operations/firewall-and-hardening.md)
- [日常运维与故障排查](docs/operations/operations-playbook.md)
- [监控、审计与持续巡检](docs/operations/monitoring-and-audit.md)
- [自建 NetBird 灾备与恢复演练](docs/operations/disaster-recovery-drill.md)

### 持续维护

- [NetBird 上游升级跟踪与兼容维护流程](docs/maintenance/upstream-upgrade-workflow.md)
- [文档治理与质量标准](docs/maintenance/documentation-governance.md)
- [NetBird 文档持续演进路线图](docs/maintenance/roadmap.md)
- [新增场景文档模板](docs/templates/case-template.md)
- [文档运营模型决策记录](docs/decisions/ADR-001-documentation-operating-model.md)
- [AI Agent 维护说明](AGENTS.md)

## 二、快速开始

### 1. 准备域名

NetBird 自建主线部署必须使用公网域名。

要求：

- 域名必须能解析到你的服务器公网 IP
- 官方自建 Quickstart 以域名为前提，不适合“只有公网 IP、没有域名”的场景
- 如果你在中国大陆面向公网使用，建议使用已备案域名，否则 HTTPS 证书签发和访问链路可能失败

```bash
export NETBIRD_DOMAIN=netbird.example.com
```

### 2. 执行官方脚本

```bash
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh | bash
```

本仓库最近核对到的官方最新稳定版是 `v0.73.2`。实际安装时仍以 `releases/latest` 指向的版本为准；如果你要先看最近版本变化，见 [NetBird 上游版本状态](docs/selfhosted/upstream-version-status.md)。

### 3. 首次打开管理界面

```text
https://netbird.example.com
```

新版官方主线默认会进入 `/setup` 页面，由你自己创建第一个管理员账号。

客户端下载入口：

```text
https://docs.netbird.io/get-started/install
```

## 三、这个仓库能帮你什么

如果你已经按官方脚本完成部署，这个仓库主要帮你补齐下面这些内容：

- 服务端配置文件该怎么看、该改哪些
- 阿里云安全组应该怎么开
- 用 NetBird 替代 OpenVPN 的具体做法
- 企业白名单系统怎么接入
- K8S 集群、Pod 网段、本地办公网络怎么打通
- 多云内网互通怎么落地
- Exit Node 和 Reverse Proxy 这些能力什么时候用、怎么配

## 四、基础端口说明

NetBird 主线部署里，最常用的对外端口如下：

| 协议 | 端口 | 作用 |
| --- | --- | --- |
| TCP | 80 | HTTP、证书申请、跳转 |
| TCP | 443 | Dashboard、管理入口、Web 登录 |
| UDP | 3478 | STUN，用于 NAT 探测和协商连接 |
| UDP | 443 | 可选，仅在启用 HTTP/3 时使用 |

如果你是第一次部署，至少先确保：

- `80/tcp`
- `443/tcp`
- `3478/udp`

这三条已放通。

## 五、阿里云安全组怎么开

如果你使用阿里云 ECS，安全组最少添加下面几条“入方向”规则：

| 方向 | 协议 | 端口范围 | 授权对象 | 作用 |
| --- | --- | --- | --- | --- |
| 入方向 | TCP | 80/80 | `0.0.0.0/0` | 证书申请、HTTP 跳转 |
| 入方向 | TCP | 443/443 | `0.0.0.0/0` | Dashboard 和 HTTPS 管理入口 |
| 入方向 | UDP | 3478/3478 | `0.0.0.0/0` | STUN |
| 入方向 | UDP | 443/443 | `0.0.0.0/0` | 可选，HTTP/3 |

新手最容易漏掉的是：

- 只开了 `443/tcp`，没开 `3478/udp`
- 域名解析好了，但 `80/tcp` 没开，导致证书失败

更详细的填写说明见：

- [阿里云安全组与端口说明](docs/operations/firewall-and-hardening.md)

## 六、域名要求

这是自建主线里最容易被忽略的一点：

- 你必须准备一个公网域名
- 这个域名必须提前解析到服务器公网 IP
- 如果没有域名，官方 Quickstart 主线通常无法正常完成 TLS 和 Web 登录链路

如果你在中国大陆使用：

- 建议直接使用已备案域名
- 否则即使服务启动，外部用户访问也可能因为域名或证书链路问题而不稳定

这不是为了“写得规范”，而是为了让控制台、认证、HTTPS 和后续场景文档都能稳定工作

## 七、仓库结构

```text
.
├── README.md
├── 部署说明.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── AGENTS.md
├── scripts/
│   └── validate-docs.sh
└── docs/
    ├── selfhosted/
    │   ├── quickstart-modern.md
    │   ├── upstream-version-status.md
    │   └── docker-compose-config-cheatsheet.md
    ├── cases/
    │   ├── 01-openvpn-replacement.md
    │   ├── 02-whitelisted-system-access.md
    │   ├── 03-kubernetes-connectivity.md
    │   ├── 04-exit-node-and-proxy.md
    │   ├── 05-multi-cloud-connectivity.md
    │   ├── 06-official-advanced-scenarios.md
    │   ├── 07-identity-provider-and-mfa.md
    │   ├── 08-device-posture-and-zero-trust.md
    │   ├── 09-automation-with-setup-keys.md
    │   └── 10-managed-kubernetes-clouds.md
    ├── operations/
    │   ├── firewall-and-hardening.md
    │   ├── operations-playbook.md
    │   ├── monitoring-and-audit.md
    │   └── disaster-recovery-drill.md
    ├── maintenance/
    │   ├── upstream-upgrade-workflow.md
    │   ├── documentation-governance.md
    │   └── roadmap.md
    ├── decisions/
    │   └── ADR-001-documentation-operating-model.md
    └── templates/
        └── case-template.md
```

## 八、官方文档入口

- 官方文档首页：https://docs.netbird.io/
- 官方客户端安装入口：https://docs.netbird.io/get-started/install
- 自建快速开始：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- 自建反向代理说明：https://docs.netbird.io/selfhosted/reverse-proxy
- 配置文件参考：https://docs.netbird.io/selfhosted/configuration-files
- 本地身份管理说明：https://docs.netbird.io/selfhosted/identity-providers/local
- 访问控制文档：https://docs.netbird.io/manage/access-control/manage-network-access
- 设备姿态检查：https://docs.netbird.io/manage/access-control/posture-checks
- Setup Keys：https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
- Kubernetes Operator：https://docs.netbird.io/manage/integrations/kubernetes
- 路由网络访问限制：https://docs.netbird.io/manage/networks/accessing-restricted-domain-resources

## 九、仓库说明

- [文档目录索引](docs/README.md)
- [开源协作说明](CONTRIBUTING.md)
- [安全响应流程](SECURITY.md)
- [AI Agent 维护说明](AGENTS.md)
- [版本变更记录](CHANGELOG.md)
