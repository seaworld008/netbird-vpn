# ADR-005: 用跨 Agent Skill 编排 NetBird 自动配置

## Status

Accepted

## Date

2026-08-19

## Context

本仓库已经把 NetBird 自建部署、Groups / Policies、Networks / Resources、Routing Peers、Kubernetes、多云、Exit Node、定向公网出口、升级和回滚写成可执行手册，也积累了多次 Dashboard、主机和 Kubernetes 实战。

用户希望 Codex、Claude Code 等 AI Agent 能直接把这些知识用于真实配置，而不是每次重新阅读全部文档或只生成概念性步骤。这个能力同时接触控制面、凭据和生产数据面，若只写一段“自动操作”提示词，容易出现以下问题：

- 没盘点现有依赖就创建重复组和平行 Policy。
- 把 Peer Connected、Pod Ready 或公网可达误当成端到端成功。
- 为定向目标误下发默认路由，影响其他流量。
- 把 Setup Key、PAT 或 Kubernetes Secret 留在仓库和日志。
- 为排障扩大到宿主机防火墙、CNI、Docker 或无关业务重启。
- Codex 与 Claude Code 使用不同项目技能目录，维护出两套漂移规则。

## Decision

1. 新增 `netbird-network-operator` Agent Skill，负责从需求、盘点、网络设计、变更预览、执行、验证到回滚的完整闭环。
2. 权威技能存放在 `.agents/skills/netbird-network-operator/`，符合 Agent Skills 的 `SKILL.md + references` 渐进加载模型，并被 Codex 作为仓库级技能发现。
3. `.claude/skills/netbird-network-operator/SKILL.md` 只作为 Claude Code 项目级发现入口，显式加载权威技能，不复制操作规则。
4. Skill 是操作编排和决策层，不成为替代 NetBird 官方 `getting-started.sh` 的安装脚本，也不在仓库维护自定义 API 客户端。
5. 执行面按现场能力选择：现有 Service User / PAT 的 Public API、官方 Ansible 集合、已登录 Dashboard 浏览器自动化、SSH / Docker / Kubernetes / 客户端 CLI。用户明确要求使用 Chrome 插件或现有已登录页面时，必须复用该浏览器和会话，不新开另一浏览器替代。
6. 只读盘点默认可执行。用户明确要求配置时，可执行目标范围内的新建和更新；删除现有访问对象、创建凭据、默认路由 / Exit Node、持久主机网络改动和生产重启必须先展示精确影响、验证与回滚，并确认已有授权覆盖该动作。
7. 自动化必须幂等和可审计：先 GET / 盘点，按名称与 ID 查重，输出保持 / 新建 / 修改 / 停用 / 删除差异，记录不含秘密的对象 ID 和结果。
8. 完成标准必须同时覆盖授权来源、非授权来源、真实业务协议、客户端路由、Routing Peer 计数、目标侧来源地址和无关业务无回归；局部健康状态不得替代数据面证据。
9. Skill 的场景路由引用仓库案例、Runbook 和 ADR；不同任务只加载相关资料。经过验证的新实战经验先脱敏，再更新 Skill reference 和必要文档。
10. `scripts/validate-docs.sh` 校验 Skill frontmatter、名称、描述、兼容入口和 OpenAI UI 元数据；同时继续执行文档链接、YAML、安全和敏感信息检查。

## Alternatives Considered

### 把全部仓库文档复制进一个 SKILL.md

可以一次加载所有知识，但上下文过大、触发成本高，也会造成重复维护，故不采用。

### 为 Codex 和 Claude Code 各维护一套完整 Skill

两个工具都能原生发现，但安全规则和场景路由容易漂移，故采用权威文件加兼容入口。

### 新增自定义 NetBird 自动配置脚本

脚本可以固定 API 请求，但要持续跟进端点、schema、认证和版本，违背本仓库不维护替代上游工具的定位。优先使用 NetBird Public API 和官方 Ansible 集合，故本次不采用自定义客户端。

### 所有写操作都无人确认

自动程度高，但删除、凭据、默认路由和生产网络变更的影响超出普通“配置访问”授权。Skill 应自动完成已授权范围，而不是扩大授权，故不采用。

## Consequences

- 用户从仓库根目录启动 Codex 或 Claude Code，即可显式调用或自动触发同一 NetBird 操作能力。
- Agent 会多做一次盘点、差异预览和跨层验收，但能显著降低重复对象、策略泄漏和误判完成的风险。
- 一次性 Dashboard 操作与可重复 API / Ansible 配置使用同一设计和验证口径。
- 已登录 Chrome 可以完成缺少 API 凭据或界面专属能力的一次性配置，但它只证明控制面对象已写入，仍需终端或目标侧证据完成数据面验收。
- Skill 被单独复制使用时仍包含核心操作规则；仓库案例链接需要访问本仓库或公开 GitHub 版本。
- 后续实战需要同时判断是更新通用 Skill、特定案例、Runbook、ADR 还是校验器，避免把现场偶然值固化为普遍规则。

## Follow-up

- 用脱敏的典型请求持续做触发和行为测试：团队权限收敛、VPC `/32`、Kubernetes Routing Peer、定向公网出口、Setup Key 接入和只读审计。
- 后续补齐 `docs/cases/14-public-api-automation.md` 时，把官方 API / Ansible 的声明式示例与本 Skill 的执行面规则互相校验。
- NetBird stable release、Public API、Ansible 集合或 Agent Skills 目录规则变化时，按仓库升级流程复核本决策。

## Official References

- <https://developers.openai.com/codex/skills>
- <https://code.claude.com/docs/en/skills>
- <https://docs.netbird.io/api/introduction>
- <https://docs.netbird.io/manage/public-api>
- <https://docs.netbird.io/selfhosted/iac/ansible>
