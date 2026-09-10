---
name: netbird-network-operator
description: 规划、审计并执行 NetBird 网络自动化配置，包括自建部署、Groups、Policies、Networks、Resources、Routing Peers、Setup Keys、客户端、Kubernetes、多云、Exit Node、定向出口、验证和回滚。用户要求用 Codex、Claude Code 等 Agent 配置、打通、授权、排障或复核 NetBird 时使用；不用于普通 WireGuard 或其他 VPN 任务。
---

# NetBird Network Operator

把用户的网络目标转换为最小权限、可验证、可回滚的 NetBird 配置，并在已有工具和授权范围内执行到端到端验收。优先使用中文说明。

## 开始前

1. 判断任务属于设计评估、只读审计、执行变更、故障排查还是回滚。用户只要求评估或审计时，不写配置。
2. 把需求写成流量契约：来源身份或设备组、目标 IP / CIDR / 域名、协议和端口、预期 Routing Peer / 出口、Masquerade、必须拒绝的来源、不得受影响的链路。
3. 先做只读盘点，不要求用户重复提供本机、现有会话或同一工作区中已经能够安全获取的信息。
4. 如果位于本手册仓库，先读 [仓库规则](../../../AGENTS.md)，再按 [场景路由](references/scenario-router.md) 只加载当前任务需要的案例、Runbook 和 ADR。
5. 若涉及实时环境，读 [执行工作流](references/execution-workflow.md)。若涉及对象和策略设计，读 [网络设计规则](references/network-design.md)。

## 执行面选择

按可用性选择最可审计、可重复的路径：

- 已有 NetBird Service User / PAT：优先使用当前部署的 Public API；凭据只从安全输入或环境读取，不打印、不写仓库。调用前确认 Management API 基址和当前官方端点结构，不猜接口。
- 用户需要声明式、可重复配置且环境允许：优先评估官方文档推荐的 `community.ansible_netbird` 集合，先展示计划和差异，再应用。
- 已登录 Dashboard：使用现有浏览器会话自动操作。用户明确指定 Chrome、浏览器插件或“现有已登录页面”时，这是硬约束，不新开浏览器、不切换到其他会话；先读 [Chrome 控制台操作](references/dashboard-chrome-operations.md)。
- 路由节点或客户端：使用已授权的 SSH、终端、Docker、Kubernetes 和 `netbird` CLI。先留基线，再做最小范围变更。

没有合适的写入能力时，完成盘点、目标模型、可复制执行计划和验证命令，明确阻塞点，不声称已经配置成功。

## 授权边界

只读盘点、状态查询和连通性探测可直接执行。用户明确要求“配置、打通、修复、应用”时，可执行目标范围内的新建和更新；该授权不自动覆盖未说明的删除、全局路由或生产重启。

在以下动作前展示精确对象、影响、验证和回滚；如果当前请求已明确包含这些对象和后果，可把它视为本次确认，否则等待确认：

- 删除、禁用或替换现有 Group、Policy、Network、Route、Peer、用户、Key。
- 创建或轮换 PAT、Setup Key、Secret 等凭据。
- 下发默认路由、启用 Exit Node、改变现有流量出口。
- 持久化宿主机路由、转发、iptables / nftables，或修改 CNI、kube-proxy、业务工作负载。
- 重启、重建、迁移生产控制面、IdP、数据库或无关服务。

禁止把真实 Token、Setup Key、私钥、客户名称、真实公网 IP 或敏感拓扑写入仓库、日志和长期记录。不得为排障清空防火墙、重启 Docker / CNI / kube-proxy 或复制同一 Peer 身份给并发实例。

## 标准闭环

1. **盘点**：记录 Peers、Groups、Users / Service Users、Setup Keys 元数据、Networks、Resources、Routing Peers、Policies、Posture Checks、DNS、legacy Routes、Exit Nodes，以及目标端和主机网络基线。
2. **建模**：画出来源组 -> Policy -> 资源组 -> Resource -> Routing Peer -> 目标的关系。发现重复旧对象、依赖、CIDR 重叠、默认全通和错误出口。
3. **预览**：列出保持、新建、修改、停用和删除对象；给每一步定义成功证据、失败停止条件和回滚动作。
4. **备份**：导出可用配置和对象清单；保存目标主机、容器或 Kubernetes 的路由、防火墙、身份目录和业务探测基线。不要把带密钥的备份提交到 Git。
5. **应用**：按依赖顺序创建组、Routing Peer 身份、Network / Resource、Policy、Posture / DNS、客户端接入。按名称查重，记录对象 ID；不并行保留意外的旧新两套访问路径。
6. **分阶段上线**：先一个来源、一个目标、一个 Routing Peer；验证通过后再扩展。Kubernetes 手工 Peer 先单节点，再恢复第二节点。
7. **验收**：按 [验证与回滚](references/verification-and-rollback.md) 完成授权、拒绝、真实协议、路由、计数、来源 IP 和无回归验证。
8. **收尾**：撤销或移除首次注册用 Key / Secret，复核对象数量和依赖，输出最终状态、证据、遗留风险和准确回滚入口。

## NetBird 不变量

- 新场景优先 `Networks + Network Resources + Policies`；legacy `Network Routes` 仅在确有需要时使用，Exit Node 仍需关注。
- 来源组、Routing Peer 组、资源组职责分离。数据库、SSH、Web 和环境边界按风险拆分，不创建方便但宽泛的 `All -> All`。
- Policy 使用真实协议和最小端口；必须验证未授权来源。NetBird 只有 ALLOW 规则，不把列表顺序当成优先级或显式 DENY。
- Policy API 的 `ports` 与 `port_ranges` 互斥；同一规则需要混合单端口和区间时，只提交 `port_ranges`，并把单端口写成 `start=end` 的范围。
- Masquerade 默认开启；关闭前必须设计目标侧回程路由并验证真实源地址。
- WireGuard 直连端口按实际 Peer 监听和容器映射核对，常见 `51820/udp`；TCP
  大范围不放行 UDP。UDP443若被HTTP/3接收，不能视为Relay QUIC已启用。
- 间歇超时先区分TCP建连与应用响应，按同一窗口的命名空间计数、定向包头和
  直连/中继对照定位，不把累计重传、Connected、QUIC Available或WS101单独当验收。
- HTTPS 依赖主机名时优先 Domain Resource，并单独验证 DNS、证书、TCP 和目标解析结果；不要在同一 Network 中混入会覆盖域名解析结果的宽 IP Range。
- 人员使用独立用户身份；Setup Key 注册设备，不代表人员。普通设备优先每机一个 One-off Key，且 One-off 只能使用一次，不能配置大于 `1` 的 `usage_limit`；批量注册必须改用短期、限次数的 Reusable Key，并在注册后撤销。
- Setup Key 只用于首次注册；长期身份来自独立持久化 `/var/lib/netbird`。两个同时在线的 Peer 不得共享身份目录。
- 多用途 Docker 主机上的 Standalone Routing Peer 默认独立 bridge + Userspace Netstack；`NB_USE_NETSTACK_MODE=true` 不等于 host 网络隔离。
- Kubernetes Routing Peer 遵守单节点先行、独立身份、业务和监控联合回归。不得仅凭 Pod Ready、Connected 或 `ping` 宣布成功。
- 指定公网 IP / 域名固定出口使用精确 Resource 和隔离的 Routing Peer；不得为定向需求下发 `0.0.0.0/0` 或 `::/0`。

## 完成标准

只有同时具备以下证据才能报告完成：

- NetBird 对象名称、ID / 精确数量、成员和依赖符合目标模型，旧访问路径按授权完成收敛。
- 授权来源的真实 TCP / HTTPS / SSH / 数据库协议成功，路由确实选择 NetBird 预期路径。
- 非授权来源没有获得 NetBird 路由或策略；公网目标即使本地直连成功，也不能被误判为策略泄漏或拒绝失败。
- 请求前后 Routing Peer 传输计数增长；固定出口场景还要有目标侧观察到的来源 IP，必要时抓包。
- DNS、证书、SNAT / 回程、应用监听和目标防火墙分别验证，不能用其中一层代替其他层。
- 无关容器、Kubernetes 网络、业务外联和监控未回归，重启次数和 `StartedAt` 未意外变化。
- 临时凭据已撤销或从运行环境移除，回滚路径仍然可用。

把结果按“目标、实际变更、验证证据、未变更范围、凭据收尾、遗留风险、回滚”汇报。没有做真实部署测试时明确写明，不用文档校验代替生产验收。

## 按需参考

- [执行工作流](references/execution-workflow.md)：授权门、工具选择、盘点、差异计划和应用顺序。
- [Chrome 控制台操作](references/dashboard-chrome-operations.md)：复用已登录 Chrome、页面盘点、对象写入和敏感字段处理。
- [网络设计规则](references/network-design.md)：对象模型、命名、最小权限、凭据和典型拓扑。
- [场景路由](references/scenario-router.md)：本仓库所有案例、Runbook 和 ADR 的选择表。
- [验证与回滚](references/verification-and-rollback.md)：跨层验收矩阵、停止条件和回滚顺序。
- [脱敏实战经验](references/live-lessons.md)：其他实战会话中已经验证或踩过的关键问题。
- [QUIC 运维](../../../docs/operations/relay-quic-runbook.md) 与
  [超时诊断](../../../docs/operations/remote-development-timeouts.md)：端口、证书、包头与多服务验收。
