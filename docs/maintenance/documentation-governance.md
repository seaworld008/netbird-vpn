# 文档治理与质量标准

> 目标：让每一篇文档都能持续维护、可验证、可复制，而不是只做概念介绍。

## 1. 文档分层

| 目录 | 定位 |
| --- | --- |
| `docs/selfhosted/` | 自建部署、版本状态、服务端配置说明 |
| `docs/cases/` | 真实场景手册，面向照步骤落地 |
| `docs/operations/` | 运维、排障、安全组、备份、升级、回滚 |
| `docs/maintenance/` | 文档自身的升级、治理、校验、贡献流程 |
| `docs/templates/` | 新增场景或变更时复用的模板 |
| `.agents/skills/` | 跨 Agent 的权威操作 Skill、按需参考和 UI 元数据 |
| `.claude/skills/` | Claude Code 发现入口，不复制权威规则 |

## 2. 场景文档必须包含

每篇 `docs/cases/*.md` 至少包含：

- 最终效果
- 工作原理
- 示例参数表
- 上线前检查
- 配置步骤
- 可复制命令或 YAML
- 授权用户验证
- 非授权用户验证
- 常见问题排查
- 回滚
- 扩展做法
- 官方参考

如果某个场景不需要其中一项，可以写“不适用”，不要直接省略。

## 3. 示例参数规范

使用文档保留地址和 RFC1918 私网地址：

| 用途 | 示例 |
| --- | --- |
| 文档公网 IP | `203.0.113.20`、`198.51.100.10` |
| 内网地址 | `10.20.0.10`、`172.16.0.10`、`192.168.10.10` |
| 域名 | `netbird.example.com`、`grafana.proxy.example.com` |
| Setup Key | `NBSETUP-...-REPLACE-ME` |

禁止写入：

- 真实公网 IP
- 真实业务域名
- 真实 token
- 真实客户、公司、人员名称
- 真实内网拓扑截图

## 4. 命令规范

命令必须满足：

- 可以复制粘贴。
- 对危险操作有前置说明。
- 对占位符明确说明如何替换。
- 优先使用非破坏性检查命令，例如 `curl -I`、`nc -vz`、`docker compose ps`。

不建议写：

```bash
rm -rf *
docker volume rm $(docker volume ls -q)
```

如果必须写破坏性命令，必须同时写清影响和备份要求。

## 5. YAML / 配置块规范

配置块必须：

- 使用正确语言标记，如 `yaml`、`bash`、`nginx`、`ini`。
- 能被基本解析器解析。
- 避免隐藏依赖，必要时写“必须修改”清单。

示例：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example
```

## 6. 官方来源引用规范

涉及 NetBird 行为、版本、参数、官方菜单路径时，优先引用官方文档或官方 release。

每篇场景文档末尾的 `官方参考` 应至少包含 2 到 5 个相关链接。

不要引用过时路径作为主参考；旧版 `how-to` 体系下的网络页面，应替换为当前 `manage/networks` 体系。

## 7. 完成定义

一次文档改动要算完成，至少满足：

- 已更新相关入口索引。
- 已记录到 `CHANGELOG.md`。
- 已执行 `./scripts/validate-docs.sh`。
- 新增场景包含验证和回滚。
- 版本相关内容已核对官方 latest。
- 如果没有真实部署测试，PR 或提交说明里明确写“仅文档级校验”。

## 8. 专家审查重点

审查文档时优先看：

- 是否会误导新手把大网段直接放给 `All`。
- 是否遗漏 Masquerade / 回程路由说明。
- 是否把 `Networks` 和 legacy `Network Routes` 混用。
- 是否把 RC 版本当稳定版。
- 是否忽略 DNS / HTTPS 证书域名问题。
- 是否只验证授权用户，没有验证非授权用户。
- 是否没有回滚步骤。
- K8S Routing Peer 是否只看 Ready / Connected，没有验证原有 Pod 外联、远端 NodePort 和监控写入。
- 是否把 Netstack 当成所有 Linux 的默认，而没有说明兼容场景和性能取舍。
- Setup Key 是否写进 YAML，或长期使用无限次 Reusable Key。

## 9. Agent Skill 质量标准

`netbird-network-operator` 的改动必须满足：

- `description` 同时写清能力、触发场景和排除边界，名称与目录符合 Agent Skills 规范。
- `SKILL.md` 只保留所有任务共用的流程和不变量；执行面、网络设计、场景、验证、Chrome 控制台和实战经验按需放在 `references/`。
- Codex / 通用 Agent 使用 `.agents/skills/` 权威内容；Claude Code 兼容入口只负责加载该内容。
- 用户指定现有已登录 Chrome 时，把浏览器选择当成硬约束，不切换会话、不读取 Cookie / Local Storage，不用控制面在线状态代替数据面验证。
- 自动化不扩大用户授权。删除、凭据、默认路由、生产网络持久化和服务重启必须有精确影响、验证、回滚及对应授权。
- 不维护自定义 NetBird API 客户端；优先当前官方 Public API、官方 Ansible 集合、Dashboard 和原生命令。
- 新实战规则必须脱敏，并能解释它改变了 Agent 的哪个决策；偶然错误和现场值不升级为普遍要求。
- 执行技能专项校验和 `./scripts/validate-docs.sh`；没有真实环境测试时明确写“技能结构与文档级校验”。

## 10. 推荐迭代方向

后续可以逐步补齐：

- 云厂商专项：阿里云 ACK、AWS EKS、GKE、AKS。
- 身份源专项：Google Workspace、Entra ID、Okta、本地用户 MFA。
- 反向代理专项：Traefik、Nginx、Nginx Proxy Manager。
- 客户端专项：Windows、macOS、Linux、移动端接入差异。
- 安全专项：posture checks、设备准入、审计日志。
- 自动化专项：Terraform、Ansible、Cloud-init、K8S Operator。
