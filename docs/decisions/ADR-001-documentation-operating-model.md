# ADR-001: 采用“官方主线 + 场景手册 + 持续校验”的文档运营模型

## Status

Accepted

## Date

2026-07-01

## Context

本仓库不是 NetBird 服务端源码仓库，也不维护自定义安装脚本。它的核心价值是把 NetBird 自建部署、配置修改、场景落地、运维排障和升级兼容写成中文可执行手册。

NetBird 官方版本和 Dashboard 功能会持续变化，尤其是下面这些能力：

- 自建部署脚本与生成文件。
- `Networks`、`Network Resources`、`Routing Peers`、legacy `Network Routes` 的推荐路径。
- Access Control、Posture Checks、Setup Keys、Reverse Proxy、Kubernetes Operator。
- 本地用户、外部 IdP、组同步、MFA 和用户生命周期管理。

如果本仓库只写一次性教程，文档会很快过期；如果仓库自己维护安装脚本，又会和官方主线产生冲突，增加新手误用风险。

## Decision

本仓库采用下面的文档运营模型：

1. 服务端部署主线始终跟随 NetBird 官方 `getting-started.sh` 与 Docker Compose 生成结果。
2. 仓库不维护替代官方脚本的安装器，不把 legacy 配置模板恢复成默认入口。
3. 具体业务场景写在 `docs/cases/`，每篇都必须包含最终效果、配置步骤、验证、排障和回滚。
4. 运维 SOP 写在 `docs/operations/`，覆盖备份、升级、回滚、监控、审计和灾备。
5. 上游兼容流程写在 `docs/maintenance/`，每次 NetBird stable release 变化都按清单更新。
6. 后续 AI agent 先读 `AGENTS.md`，再改文档；提交前运行 `./scripts/validate-docs.sh`。
7. 重要文档组织方式和不可逆方向用 ADR 记录，放在 `docs/decisions/`。

## Alternatives Considered

### 继续做单一 README

优点是入口简单。

缺点是场景、运维、升级、治理会混在一起，后续新增 Kubernetes、IdP、审计、灾备内容时会变得很难维护。

结论：不采用。

### 维护自定义安装脚本

优点是可以把部署体验完全固定下来。

缺点是 NetBird 官方脚本、镜像、配置结构变化后，本仓库需要承担安装器兼容成本，也容易误导新手偏离官方路径。

结论：不采用。

### 只链接官方文档

优点是维护成本低。

缺点是官方文档不一定覆盖中文新手、阿里云安全组、企业白名单、K8S 私有网络、多云内网、具体回滚和验证清单等本地实践。

结论：不采用。

## Consequences

- 每次新增场景都要同步更新入口索引、`CHANGELOG.md` 和相关维护文档。
- 每次 NetBird stable release 更新都要核对官方 release、官方文档和本仓库案例。
- 本仓库文档会更像运维手册，而不是博客文章。
- 后续 Agent 可以基于 `AGENTS.md`、ADR 和模板持续扩写，而不必重新判断仓库定位。

## Follow-up

- 持续维护 `docs/maintenance/roadmap.md`。
- 新增重大文档组织决策时创建 `ADR-002`、`ADR-003`。
- 如果未来仓库真的需要脚本或 Helm Chart，必须先写新的 ADR 说明原因、边界和回滚策略。
