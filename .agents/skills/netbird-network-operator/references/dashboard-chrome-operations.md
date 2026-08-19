# Chrome 控制台操作

本参考用于 Codex、Claude Code 等 Agent 通过浏览器插件，直接操作用户已经登录的 NetBird Dashboard。它是完整执行面，不是只能查看页面的后备模式。

## 1. 会话约束

- 用户指定 Chrome、Chrome 插件、外部浏览器或“现有已登录页面”时，复用该浏览器、现有标签页和登录状态；不要新开另一种浏览器，也不要切换到未获授权的 NetBird 实例。
- 浏览器插件不可用时，说明需要连接对应浏览器插件；不要偷偷改用独立 Playwright、无头浏览器、Web 搜索或另一个登录会话。
- 如果当前 Chrome 页面要求登录，请让用户在同一 Chrome 中完成登录后继续；不绕过 MFA，不读取或导出密码、Cookie、Local Storage、Session Storage 和浏览器配置文件。
- 页面上存在多个 NetBird 域名、Account 或 MSP Tenant 时，先向用户展示当前可见实例和租户；写入前锁定目标，不能根据旧标签页或历史值猜测。
- 用户只要求使用现有控制台时，不额外创建 PAT 或 Service User。只有用户需要后续 API / IaC 自动化且明确同意时，才评估凭据方案。

## 2. 连接后先盘点

先读取当前页面的可见状态，再按菜单逐项盘点。菜单名称以当前版本实际显示为准，不硬编码旧路径：

| 区域 | 盘点内容 |
| --- | --- |
| Peers | 名称、NetBird IP、在线、Last Seen、OS、Groups、是否候选 Routing Peer |
| Access Control > Groups | 成员、Users、Peers、Policies、Resources、Routes、Keys 依赖 |
| Access Control > Policies | 来源、目标、方向、协议、端口、Posture、启用状态 |
| Networks | Resources、Routing Peers、Masquerade、DNS Resolution、资源组 |
| Network Routes / Exit Nodes | 前缀、分发组、Routing Peer 组、Masquerade、启用状态 |
| Setup Keys | 名称、类型、过期、使用限制、自动分组、撤销状态；不读取旧明文 |
| Team / Users / Service Users | 用户状态、角色、组、身份来源、Token 元数据 |
| DNS / Posture Checks | 分发组、匹配条件、关联 Policy |

浏览器盘点只记录完成任务所需的对象。不要下载全量客户数据或保存含敏感拓扑的截图到仓库。

## 3. 页面操作纪律

1. 每次进入菜单、切换标签、打开弹窗、保存或删除后，都重新读取当前页面状态。React / 动态页面可能重建元素，旧 selector、旧节点引用和旧坐标都可能失效。
2. 通过可见标签、角色、输入名称和当前层级定位控件；不要依赖一次会话中碰巧成立的元素序号。
3. 页面还在加载或选项未出现时，等待当前导航完成并重新读取，不连续点击或使用过期 selector。
4. 新建前先在当前列表和搜索框查精确名称。出现同名对象时打开详情核对 ID / 依赖，不加 `-new`、`-2` 逃避冲突。
5. 保存后的 toast、弹窗关闭或按钮变灰只表示提交动作发生；重新进入详情，核对精确字段、成员和对象数量。
6. 删除后同时证明旧对象不在、目标对象仍在、依赖未悬空。若页面显示对象仍有依赖，停止并重新盘点。
7. 操作超时不等于服务失败。先判断是页面导航、控件渲染、API 返回还是 NetBird 后端错误，再决定是否重试。

## 4. 推荐的控制台创建顺序

在目标模型获准后按依赖操作：

1. `Groups`：来源、Routing Peer、资源职责分离。
2. `Setup Keys`：仅在需要新 Peer 注册时创建短期 Key，并设置准确 Auto-assigned Group。
3. `Peers`：确认新 Peer 在线、资产名正确且只加入预期组。
4. `Networks`：创建 Network、绑定 Routing Peer、设置 Masquerade / DNS Resolution。
5. `Resources`：按 `/32`、最小 Range 或 Domain 创建并放入资源组。
6. `Policies`：来源到资源组，使用真实协议和最小端口；先测试组。
7. `Posture / DNS / IdP`：只有业务契约需要时追加，先小范围验证。
8. 完成授权、非授权和数据面验证后，再按用户授权停用或删除旧路径。

若现有环境对象顺序不同，以依赖关系为准，不为了遵循顺序重建健康对象。

## 5. 一次性密钥和敏感字段

- Setup Key、PAT 等明文通常只显示一次。不要在聊天、截图、终端历史、剪贴板日志或长期笔记中复述完整值。
- 如果后续需要在已授权主机注册 Peer，使用宿主工具支持的安全输入或临时变量传递；命令和输出中遮蔽值。
- Key 注册成功并确认身份目录持久化后，在 Dashboard 撤销 Key，并从容器环境、Kubernetes Secret 或临时文件移除。
- 只保留 Key 名称、类型、到期、usage limit、状态、关联组和审计事件。
- 浏览器控制能力不授权读取浏览器内部认证材料，也不授权从页面请求中提取会话 Token 作为 API Token。

## 6. 控制台能证明什么

Chrome 可以证明：

- 对象已经创建、更新、启用、停用或删除。
- Group 成员和对象依赖符合目标。
- Peer 在控制面显示在线，并收到预期 Network / Policy 元数据。

Chrome 不能单独证明：

- 客户端路由确实选择 NetBird。
- Routing Peer 到目标的 TCP、DNS、SNAT 和回程正常。
- 固定公网出口被目标观察为获准 IP。
- Kubernetes CNI、业务 Pod 外联和监控没有回归。
- 非授权公网目标没有走本地互联网直连。

因此，控制台配置完成后继续使用已授权的客户端、SSH、Docker、Kubernetes 或目标日志，执行 [验证与回滚](verification-and-rollback.md)。如果缺少这些执行面，报告“控制面已配置、数据面待验证”，不能报告网络已经打通。

## 7. 常见恢复

- 菜单或列表空白：确认当前页面和租户，重新读取可见导航；不要直接猜 URL。
- Group / Policy 选择器超时：等待导航完成，重新打开弹窗并读取当前选项。
- 保存后找不到对象：清除当前搜索条件、刷新列表并按精确名称复核；再检查是否处于错误 Tenant。
- 删除提示成功但行仍存在：重新加载列表和详情，检查依赖与后端返回；不要反复点击删除。
- 会话失效：保留当前任务状态，让用户在同一 Chrome 重新登录，再从只读复核继续。
