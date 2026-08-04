# NetBird 文档持续演进路线图

> 目标：让这个仓库能随着 NetBird 官方版本、团队使用场景和运维经验持续升级，而不是停留在某一次部署记录。

## 1. 当前定位

本仓库当前已经覆盖：

- 官方脚本自建部署入口。
- Docker Compose 生成文件说明。
- OpenVPN 替代、白名单系统、K8S、多云、Exit Node、Reverse Proxy。
- 身份源、设备姿态、Setup Key 自动化、托管 K8S 云厂商差异。
- VPC 单主机精确授权、跨平台客户端接入、Legacy 外部 IdP 升级。
- 日常运维、监控审计、备份、升级、回滚。
- 上游版本跟踪、文档治理、AI Agent 维护说明。

下一阶段的目标不是简单堆文章，而是把文档做成可持续迭代的知识库。

## 2. 维护节奏

| 节奏 | 动作 | 输出 |
| --- | --- | --- |
| 每周 | 检查用户反馈、失效链接、文档 TODO | 小修文档或记录 backlog |
| 每月 | 核对 NetBird stable release 与官方文档重点页面 | 更新版本状态和兼容说明 |
| 每季度 | 复盘生产案例、补齐缺失场景、清理重复内容 | 更新路线图和 `CHANGELOG.md` |
| 每次重大升级 | 在测试环境验证核心链路 | 更新升级流程、案例验证命令和排障项 |

## 3. 文档成熟度模型

每篇场景文档都按 4 个等级演进：

| 等级 | 标准 |
| --- | --- |
| L1 概念可读 | 能解释用途、适用范围和工作原理 |
| L2 操作可跑 | 有完整命令、YAML、配置字段和验证步骤 |
| L3 运维可管 | 有排障、回滚、监控、审计和安全注意事项 |
| L4 升级可持续 | 标注官方来源、版本影响面和后续维护点 |

新增文档最低必须达到 L2；生产推荐场景应逐步达到 L3；涉及 NetBird 核心能力的文档应达到 L4。

## 4. 优先级 backlog

### P0：保持仓库不误导新手

- 官方 latest 版本变化后更新 `README.md`、`部署说明.md`、`docs/selfhosted/upstream-version-status.md`。
- 修复失效链接、错误菜单路径、错误命令。
- 新增案例必须有验证和回滚。
- 所有 YAML 代码块必须能被解析。

### P1：补齐生产化能力

- 反向代理生产专项：Traefik、Nginx、Nginx Proxy Manager、证书、真实客户端 IP、HTTP/3。
- 移动客户端专项：iOS、Android 的安装、登录、MDM 下发和常见问题。
- Public API 自动化专项：创建用户、邀请用户、Setup Key、资源、策略的安全脚本范式。
- 审计专项：Activity、用户生命周期、Setup Key 使用、临时策略关闭。
- 灾备专项：备份恢复演练、跨主机恢复、DNS 切换、RPO/RTO。

### P2：增强企业级实践

- 企业 IdP 深入文档：Google Workspace、Microsoft Entra ID、Okta、Keycloak、SCIM。
- MDM / EDR 深入文档：受管设备、客户端版本门槛、进程检查、离职设备回收。
- 多环境模板：开发、测试、生产的 Groups、Networks、Resources、Policies 命名规范。
- 合规审查模板：变更审批、访问复核、审计留痕、密钥轮换。

## 5. NetBird 升级观察点

每次上游升级优先观察：

- `getting-started.sh` 是否改变生成文件和默认容器。
- `config.yaml` 字段是否新增、废弃或迁移。
- 本地用户、嵌入式 IdP、外部 IdP、MFA 是否有新限制。
- `Networks` 与 legacy `Network Routes` 的 Dashboard 入口是否调整。
- Routing Peer、Masquerade、Exit Node、Reverse Proxy 是否改变默认行为。
- Kubernetes Operator 的 Helm Chart、CRD、权限和镜像是否变化。
- Setup Key、ephemeral peer、自动分组是否新增字段。
- Posture Checks 的评估时机、支持平台和检查项是否变化。

## 6. 新文档立项规则

新增一篇文档前先判断：

1. 是否有真实用户会照着做。
2. 是否能给出完整配置、命令或 YAML。
3. 是否能写出失败时怎么排查。
4. 是否能写出怎么撤回。
5. 是否能引用官方来源或明确标注经验判断。

如果只能写概念，不要放进 `docs/cases/`；可以先放进 backlog，等有可执行步骤后再落地。

## 7. 完成一次迭代的检查清单

每次文档迭代结束前执行：

```bash
git status --short --branch
./scripts/validate-docs.sh
git diff --stat
```

并确认：

- 入口索引已更新。
- `CHANGELOG.md` 已更新。
- 新增链接没有断。
- 示例没有真实密钥、真实公网 IP、真实客户信息。
- 没有把 RC 版本写成默认稳定版本。
- 没有只写授权用户验证而遗漏非授权用户验证。

## 8. 下一批建议补齐文档

可以按下面顺序继续：

1. `docs/cases/13-reverse-proxy-production-hardening.md`
2. `docs/cases/14-public-api-automation.md`
3. `docs/cases/15-enterprise-idp-deep-dive.md`
4. `docs/cases/16-mdm-edr-device-compliance.md`
5. `docs/cases/17-mobile-client-onboarding.md`

这些文件未创建前，不要在 README 里做成正式入口；可以在 `AGENTS.md` 或本路线图里作为后续方向维护。
