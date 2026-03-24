# CHANGELOG

## Unreleased

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
