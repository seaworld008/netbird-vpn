# 贡献指南

## 1. 提交范围

本仓库主要用于：

- NetBird 自建部署文档（官方推荐与兼容路径）
- 运维/故障排查最佳实践
- 场景化参考手册（OpenVPN 替代、K8S 接入、多云互联等）

请优先提交：

- 文档改进（步骤、截图、命令）
- 新增场景模板（附验收清单）
- 部署兼容矩阵更新

## 2. 分支与提交规范

- 使用语义化提交标题：`docs: ...`、`fix: ...`、`chore: ...`
- 中文优先，必要时添加英文关键词

建议格式：

```text
docs: 添加 OpenVPN 替代场景的验证清单
fix: 修正部署脚本兼容变量文案
chore: 增加安全策略与贡献指引
```

## 3. 文档 PR 流程

1. 先确认场景是否已有相似文档
2. 在文档中标注前提条件与适用范围
3. 补齐以下三项：
   - 环境准备
   - 验证步骤
   - 回滚/故障排查建议
4. 提交 PR 时在说明里写明“测试状态”（如未执行部署，仅文档级校对）
5. 提交前执行：

```bash
./scripts/validate-docs.sh
```

## 4. 命名与路径约定

- `docs/cases/`：按场景分类
- `docs/selfhosted/`：安装与架构决策
- `docs/operations/`：运维与巡检流程
- `docs/maintenance/`：上游升级跟踪、文档治理、质量标准
- `docs/decisions/`：影响长期维护方式的 ADR 决策记录
- `docs/templates/`：新增文档模板
- `AGENTS.md`：给 AI agent 和后续维护者的仓库操作说明

新增场景文档时，优先复制：

```bash
cp docs/templates/case-template.md docs/cases/NN-your-case.md
```

## 5. 禁止提交内容

- 不要提交明文密钥、token、私钥、真实内网拓扑中的敏感地址
- 不要提交未经验证的危险命令（尤其是 `rm -rf`、`curl | bash` 的变种）

## 6. 上游升级维护

当 NetBird 官方发布新版 stable release 时，按下面流程更新：

- `docs/maintenance/upstream-upgrade-workflow.md`
- `docs/selfhosted/upstream-version-status.md`
- `CHANGELOG.md`

不要把 RC 版本写成本仓库默认部署目标。

## 7. 什么时候写 ADR

如果改动会影响仓库长期维护方式，例如新增脚本、改变部署主线、调整目录结构、引入新的默认部署平台，请先在 `docs/decisions/` 新增一篇 ADR。

ADR 需要写清：

- 背景
- 决策
- 被放弃的替代方案
- 后果
- 后续动作
