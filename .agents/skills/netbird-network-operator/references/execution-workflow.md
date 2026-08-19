# 执行工作流

本参考用于实时 NetBird 环境的设计、变更、审计、排障和回滚。所有名称和地址先从现场盘点，不套用示例值。

## 1. 任务模式

| 模式 | 默认动作 | 写入边界 |
| --- | --- | --- |
| 设计评估 | 盘点、画目标模型、比较方案 | 不写入 |
| 只读审计 | 查询 Dashboard / API / 主机，输出证据 | 不写入 |
| 执行配置 | 盘点、预览、应用、验证、收尾 | 仅限用户明确目标 |
| 故障排查 | 从症状到分层证据，先隔离最小组件 | 未要求修复时不写入 |
| 回滚 | 按原对象和基线恢复 | 只撤回本次或明确指定变更 |

“全自动”表示 Agent 负责把已授权范围做完，不表示跳过凭据、删除、默认路由、生产重启等高影响动作的授权门。

## 2. 流量契约

开始时整理以下字段，未知项通过只读检查补齐：

```text
业务目标：
来源用户 / 设备 / 工作负载：
来源组：
目标 IP / CIDR / Domain：
协议和端口：
预期 Routing Peer / 出口：
Masquerade / 目标侧预期源地址：
必须拒绝的来源：
不得受影响的服务、网络和默认流量：
维护窗口或中断上限：
回滚负责人和入口：
```

公网目标需要额外写明：客户端本地是否也能直接访问、只有少量目标定向出口还是所有互联网流量走 Exit Node、目标白名单实际放行哪个公网 IP。

## 3. 执行面决策

### Public API

适合批量、可重复、需要精确对象 ID 和差异记录的任务。

1. 优先使用专用 Service User 的短期 PAT；组织级自动化不绑定个人账号。
2. 从安全输入读取 `NETBIRD_API_URL` 和 Token。命令回显、调试日志和结果文件不得出现 Token。
3. 先用 GET 构建实际对象索引，再生成期望状态差异。按名称匹配时同时核对 ID 和依赖，避免同名误改。
4. 写请求前查看当前官方 API 文档或部署暴露的 schema。不要凭记忆猜字段、DELETE 路径或请求体。
5. 每个写请求保存不含密钥的请求摘要、响应状态和对象 ID；处理 `409`、`422`、`429` 时先重新读取状态，不盲目重复写入。
6. 多租户 / MSP 环境显式锁定 account / tenant，禁止凭当前页面猜目标租户。

全新自托管、嵌入式身份且尚未创建任何 Owner 时，可以评估官方 setup-time PAT：只在受控初始化窗口临时启用 `NB_SETUP_PAT_ENABLED=true`，禁止记录返回体，初始化后立即禁用，并改用专用 Service User Token。已有账号的实例不得为了获取 Token 重开 setup 流程。

官方入口：

- <https://docs.netbird.io/api/introduction>
- <https://docs.netbird.io/manage/public-api>
- <https://docs.netbird.io/api/guides/authentication>
- <https://docs.netbird.io/selfhosted/automated-setup>

### 官方 Ansible 集合

用户要求声明式、可重放配置，并允许新增受版本控制的 IaC 时，评估 `community.ansible_netbird`：

- 先确认 Ansible、Python、集合版本和 NetBird 当前版本兼容。
- Secret 只通过 Vault、CI Secret 或环境注入。
- 先 `--check --diff` 或模块等价预览，再应用。
- 不让声明式清单接管未纳入本次范围的已有对象。

官方入口：<https://docs.netbird.io/selfhosted/iac/ansible>

### Dashboard 浏览器自动化

适合已有登录会话的一次性配置或 API 不可用时：

1. 只在用户指定或当前已登录的租户中操作。
2. 每次导航、保存、弹窗关闭后获取新页面状态；页面元素可能因加载而重建。
3. 先搜索精确名称并记录依赖，再新建或修改。
4. 保存后的 toast 只算动作反馈；重新进入列表或详情，按精确名称、成员和数量复核。
5. 删除必须先确认依赖已迁移，删除后同时验证旧行消失、目标行仍存在。

用户指定 Chrome 插件、外部浏览器或已有登录页时，继续按 [Chrome 控制台操作](dashboard-chrome-operations.md) 执行，不为了“更方便”创建 PAT、打开另一浏览器或替换登录会话。

### 主机、客户端和 Kubernetes

- SSH / 终端先记录主机名、时间、接口、路由、策略路由、转发、iptables / nftables、监听端口和相关进程。
- Docker 记录网络、业务容器 DNS/TCP、`StartedAt`、`RestartCount`，Routing Peer 使用独立项目和身份目录。
- Kubernetes 记录节点、Pod / Service CIDR、CNI、kube-proxy、普通 Pod 外联和监控基线；修改 Routing Peer 不顺带修改业务 Deployment。
- 客户端记录 `netbird status -d`、路由表、DNS、其他 VPN 和本地 LAN，特别检查 CIDR 重叠与最长前缀。

## 4. 只读盘点

至少建立以下清单：

| 对象 | 需要记录 |
| --- | --- |
| Account / Tenant | 名称、ID、部署 URL、版本、身份模式 |
| Users / Service Users | 状态、角色、组、MFA / IdP 来源 |
| Peers | ID、名称、OS、NetBird IP、连接、Last Seen、组、SSH、是否 Routing Peer |
| Setup Keys | 名称、类型、过期、usage limit、auto groups、已用次数、撤销状态；不记录明文 |
| Groups | ID、名称、Peers / Users、Policy / Resource / Route / Key 依赖 |
| Networks | ID、Resources、Routing Peers、Masquerade、DNS Resolution |
| Policies | 来源组、目标组、方向、协议、端口、Posture、启用状态 |
| Legacy Routes / Exit Nodes | 前缀、Routing Peer 组、分发组、Masquerade、metric / priority、启用状态 |
| DNS / Posture | 分发组、匹配条件、失败影响 |
| Hosts / K8S | 路由、NAT、防火墙、CNI、业务和监控基线 |

同时盘点现有旧路径。若用户要“只保留一套”，先画出旧组、旧策略、旧 Key 和新对象的依赖关系，不能只创建新对象后留下平行授权。

## 5. 目标模型和差异预览

按以下格式输出并用于执行：

| 动作 | 对象类型 | 精确名称 / ID | 影响 | 验证 | 回滚 |
| --- | --- | --- | --- | --- | --- |
| 保持 |  |  |  |  |  |
| 新建 |  |  |  |  |  |
| 修改 |  |  |  |  |  |
| 停用 |  |  |  |  |  |
| 删除 |  |  |  |  |  |

默认先创建并验证新路径，再停用旧路径；删除只在用户明确要求收敛且新路径已通过授权和拒绝测试后进行。避免为了“干净”删除仍被其他团队使用的共享对象。

## 6. 应用顺序

1. 创建或确认来源组、Routing Peer 组和资源组。
2. 准备 Routing Peer 主机 / Pod、独立身份目录和短期 Setup Key；先一个实例注册。
3. 创建 Network，再创建最小的 IP、IP Range 或 Domain Resource，并绑定正确 Routing Peer。
4. 创建最小协议和端口 Policy；先绑定测试来源组。
5. 按需添加 Posture Check、DNS 或 IdP 组同步，避免一次引入多个未知失败面。
6. 让一个授权端和一个非授权端验证，再扩大成员或第二 Routing Peer。
7. 撤销首次注册 Key，删除运行环境中的 Secret，验证无 Key 重建仍复用原身份。
8. 按授权停用 / 删除旧路径，重新统计目标对象和依赖。

API 和 Dashboard 写入都应尽量幂等：存在且完全匹配时保持；存在但不同先比较；不要用自动生成的新名称逃避冲突。

## 7. 最终记录

```text
目标：
执行面：API / Ansible / Dashboard / SSH / Kubernetes
新增：
修改：
停用 / 删除：
明确未改：
授权测试：
非授权测试：
数据面证据：
业务无回归：
凭据收尾：
遗留风险：
回滚入口：
```
