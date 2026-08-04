# AGENTS.md

> 本文件给后续 AI agent、自动化助手和维护者使用。进入仓库后先读本文件，再改文档。

## 1. 仓库定位

这是一个 NetBird 自建部署与实践手册仓库，目标是做成“入门 + 进阶 + 实战 + 运维”的中文用户手册。

核心读者：

- 第一次自建 NetBird 的个人或团队。
- 想用 NetBird 替代 OpenVPN 的运维人员。
- 需要接入 K8S、多云、内网白名单系统、Exit Node、Reverse Proxy 的工程团队。
- 后续维护文档、跟进 NetBird 官方升级的 AI agent。

本仓库不是 NetBird 服务端源码仓库，也不维护自定义部署脚本。

## 2. 不可改变的主线原则

- 所有回复、文档说明优先使用中文。
- 服务端部署主线：官方 `getting-started.sh` 生成结果 + Docker Compose。
- 不恢复 legacy 配置模板作为默认路径。
- 不自己维护替代官方脚本的安装脚本。
- 场景文档必须可复制、可验证、可排障、可回滚。
- 上游版本以 GitHub `releases/latest` 且 `prerelease=false` 为稳定版本依据。
- RC 标签只能作为观察项，不写成本仓库默认部署目标。
- 示例中使用文档保留地址、RFC1918 私网地址和 `example.com` 域名，不写真实敏感信息。

## 3. 目录说明

```text
.
├── README.md
├── 部署说明.md
├── AGENTS.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
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
    │   ├── 10-managed-kubernetes-clouds.md
    │   ├── 11-precision-vpc-access.md
    │   └── 12-client-platform-onboarding.md
    ├── operations/
    │   ├── containerized-routing-peer-runbook.md
    │   ├── firewall-and-hardening.md
    │   ├── operations-playbook.md
    │   ├── monitoring-and-audit.md
    │   ├── disaster-recovery-drill.md
    │   └── legacy-external-idp-upgrade.md
    ├── maintenance/
    │   ├── upstream-upgrade-workflow.md
    │   ├── documentation-governance.md
    │   └── roadmap.md
    ├── decisions/
    │   ├── ADR-001-documentation-operating-model.md
    │   └── ADR-002-pinned-images-and-routing-peer-isolation.md
    └── templates/
        └── case-template.md
```

## 4. 每次接手先做什么

在仓库根目录执行：

```bash
git status --short --branch
git pull --ff-only origin main
rg --files
```

如果工作区已有未提交改动：

- 不要回滚。
- 先读 `git diff --stat` 和相关文件。
- 在已有改动基础上继续。

## 5. 更新 NetBird 上游版本的方法

执行：

```bash
curl -s https://api.github.com/repos/netbirdio/netbird/releases/latest | jq -r '.tag_name, .published_at, .html_url, .prerelease'
git ls-remote --tags --sort='v:refname' https://github.com/netbirdio/netbird.git | tail -30
git ls-remote https://github.com/netbirdio/netbird.git HEAD refs/heads/main
```

更新时至少检查：

- `README.md`
- `部署说明.md`
- `docs/selfhosted/upstream-version-status.md`
- `docs/selfhosted/quickstart-modern.md`
- `docs/selfhosted/docker-compose-config-cheatsheet.md`
- `docs/cases/*.md`
- `docs/operations/*.md`
- `CHANGELOG.md`

详细流程见：

- `docs/maintenance/upstream-upgrade-workflow.md`

## 6. 新增或扩写场景文档的方法

优先复制模板：

```bash
cp docs/templates/case-template.md docs/cases/NN-your-case.md
```

场景文档至少包含：

- 最终效果
- 工作原理
- 示例参数
- 上线前检查
- 配置步骤
- 可复制命令 / YAML
- 授权用户验证
- 非授权用户验证
- 排障
- 回滚
- 扩展做法
- 官方参考

不要只写概念说明。用户应该能按文档一步步操作，并知道失败时怎么查。

## 7. NetBird 概念口径

优先使用这些当前主线概念：

- `Networks`：新场景优先使用，资源和策略边界更清晰。
- `Routing Peer`：连接 NetBird overlay 和内网/VPC/K8S 的桥。
- `Network Resources`：IP、IP Range、Domain。
- `Access Control > Groups / Policies`：最小权限控制。
- `Setup Keys`：服务器、路由节点、容器、K8S Pod 非交互式接入。
- `Network Routes`：仍可用，但更偏 legacy；Exit Node 场景仍需要关注。
- `Masquerade`：默认建议开启，便于回程；关闭时必须写回程路由。
- `Domain Resource`：HTTPS 证书依赖域名时优先使用。

常见危险点：

- 不要让新手直接创建 `All -> All` 或大网段全放。
- 不要把数据库、SSH、Web 混在一个大资源组。
- 不要忽略非授权用户验证。
- 不要只写 `ping` 作为验证，很多策略没有放 ICMP。

## 8. 官方文档优先级

写 NetBird 行为时，优先参考：

- https://docs.netbird.io/selfhosted/selfhosted-quickstart
- https://docs.netbird.io/selfhosted/configuration-files
- https://docs.netbird.io/manage/networks/how-routing-peers-work
- https://docs.netbird.io/manage/networks
- https://docs.netbird.io/manage/network-routes
- https://docs.netbird.io/manage/network-routes/use-cases/exit-nodes
- https://docs.netbird.io/manage/access-control/manage-network-access
- https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
- https://docs.netbird.io/manage/reverse-proxy
- https://docs.netbird.io/use-cases/cloud/routing-peers-and-kubernetes
- https://docs.netbird.io/manage/integrations/kubernetes

如果官方页面路径变化，更新所有相关引用，并运行校验。

## 9. 本地校验

每次提交前执行：

```bash
./scripts/validate-docs.sh
```

如果没有执行权限：

```bash
bash scripts/validate-docs.sh
```

这个脚本会检查：

- 本地 Markdown 链接。
- Markdown 代码围栏。
- YAML 代码块解析。
- 旧版本号和旧官方路径残留。
- `git diff --check`。

## 10. 提交流程建议

```bash
git checkout -b codex/<short-topic>
./scripts/validate-docs.sh
git add <files>
git commit -m "docs: <summary>"
git push -u origin codex/<short-topic>
gh pr create --base main --head codex/<short-topic>
```

PR 描述至少包含：

- 改了哪些文档。
- 为什么改。
- 是否核对官方最新版本。
- 执行了哪些校验。
- 是否做过真实部署测试。

## 11. 安全要求

禁止提交：

- 真实 token、Setup Key、API Key、私钥。
- 真实客户名称或内部系统域名。
- 真实公网 IP 或敏感内网拓扑。
- 未说明影响的破坏性命令。

示例 Setup Key 使用：

```text
NBSETUP-EXAMPLE-REPLACE-ME
```

示例域名使用：

```text
netbird.example.com
grafana.proxy.example.com
```

## 12. 后续优先补齐方向

维护者或 AI agent 可以优先补：

1. `docs/cases/13-reverse-proxy-production-hardening.md`：Traefik、Nginx、Nginx Proxy Manager、证书和真实客户端 IP。
2. `docs/cases/14-public-api-automation.md`：用户、邀请、Setup Key、资源、策略的自动化管理。
3. `docs/cases/15-enterprise-idp-deep-dive.md`：Google Workspace、Microsoft Entra ID、Okta、Keycloak、SCIM 深入实践。
4. `docs/cases/16-mdm-edr-device-compliance.md`：MDM、EDR、设备准入、离职设备回收。
5. `docs/cases/17-mobile-client-onboarding.md`：iOS、Android 安装、登录、MDM 下发和常见问题。

新增时遵循 `docs/templates/case-template.md`。
路线图见 `docs/maintenance/roadmap.md`；重大组织方式变化先写 `docs/decisions/ADR-XXX-*.md`。
