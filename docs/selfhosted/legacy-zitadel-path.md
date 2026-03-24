# 兼容路径：Zitadel 方案（getting-started-with-zitadel.sh）

> 本页用于保持对历史环境的兼容，不建议作为新环境默认选择。  
> 仍然建议先跑官方脚本生成基础文件，仅在必要时按需覆盖。

## 适用情况

- 你的组织已经有成熟 Zitadel 身份服务，且团队已有运维能力。
- 你需要在最小改造条件下复用现有 SSO 或组织管理体系。

## 一条命令执行

```bash
export NETBIRD_DOMAIN=netbird.example.com
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh | bash
```

> `deploy.sh` 作为历史兼容入口保留，但本仓库默认流程不再依赖本地脚本。

## 迁移建议

1. 保留现有 `zitadel.env` 与证书路径策略，不要直接替换为本地用户模型。
2. 对新功能（例如策略模板、路由策略）先在测试环境验证。
3. 业务平滑迁移时可保留旧部署与新部署并行跑一段时间。
4. 逐步迁移组与策略后，再切换为现代脚本（按需）以降低系统复杂度。

## 注意事项

- 新版文档默认路径和端口映射规则会变化，若你保留旧版部署，优先按实际 compose 文件对照端口。
- 切换前先做数据库与证书备份。
