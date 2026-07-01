# CHANGELOG

## Unreleased

- 更新 2026-07-01 NetBird 上游最新稳定版核对状态，当前 `releases/latest` 指向 `v0.73.2`
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
