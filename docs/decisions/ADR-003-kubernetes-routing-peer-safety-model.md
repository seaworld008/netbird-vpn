# ADR-003: Kubernetes Routing Peer 使用分阶段发布和兼容数据面

## Status

Accepted

## Date

2026-08-13

## Context

集群内 Routing Peer 同时接触 NetBird Overlay、CNI、kube-proxy、宿主机
netfilter 和业务 Pod 出站链路。只检查 Peer Connected 或 Pod Ready，无法证明
集群网络没有回归。

旧内核、CentOS 7、legacy iptables 与 nftables 混用环境，可能在 Routing Peer
启动后出现同节点 Pod 远端 NodePort、外联或监控 remote-write 超时。DNS 仍可能
正常，因此把故障直接归因于 CoreDNS 会遗漏真实的数据面问题。

同时，官方 Kubernetes Operator 已能通过 `NetworkRouter`、`NetworkResource`、
多副本和 PDB 提供现代 Service 暴露路径。仓库不应把手工高权限 Pod 写成所有
集群的统一默认方案。

## Decision

1. 现代集群、具体 Service 暴露优先使用官方 Kubernetes Operator。
2. 旧集群或需要整个 Pod / Service CIDR 时，允许使用受控节点上的手工
   DaemonSet，但不得默认覆盖所有节点。
3. 手工 Peer 默认不使用 `hostNetwork`，每个节点使用独立持久身份目录。
4. Setup Key 只用于首次注册；使用短有效期和明确 usage limit，注册后撤销并从
   Kubernetes 删除。
5. Linux 默认保留官方原生数据面。只有可逆隔离证明存在旧内核 / netfilter
   兼容问题时，才持久化 `NB_USE_NETSTACK_MODE=true`。
6. 上线顺序固定为单 Peer 验证、集群无回归验证、再恢复第二 Peer。
7. 验收必须覆盖授权与非授权客户端、Pod IP、ClusterIP、远端 NodePort、Pod
   外联和监控 remote-write；不能只看 `ping`、Connected 或 Ready。
8. 故障时优先只隔离可疑节点上的 Routing Peer，不先重启 CNI、kube-proxy 或
   业务 Pod。
9. 持久化 YAML 是唯一声明源，临时在线 Patch 不作为长期配置。
10. Network Resources 使用专用资源组和最小端口 Policy，不创建 `All -> All`。

## Alternatives Considered

### 所有节点运行 privileged DaemonSet

部署简单，但扩大内核网络、凭据和升级的影响范围，故不采用。

### 所有 Linux 集群默认启用 Netstack

兼容性更强，但会牺牲峰值吞吐，也掩盖现代内核本可正常使用的原生数据面，故
仅作为有证据的兼容模式。

### 只检查 Routing Peer Ready

探针只能证明 NetBird 守护进程状态，不能证明业务 Pod SNAT、远端 NodePort 和
监控写入正常，故不采用。

### 长期保存无限次 Reusable Setup Key

便于自动扩容，但泄露后可持续注册高权限 Peer。自动扩容场景应使用 Operator、
Ephemeral Peer 或外部 Secret 管理，并设置明确限制。

## Consequences

- 首次上线和升级步骤更多，但故障域更小，回滚更明确。
- 手工 DaemonSet 的节点替换需要重新发放 Key 或恢复该节点自己的身份备份。
- Netstack 模式需要单独做吞吐和 CPU 验证。
- 文档和 AI agent 必须同时关注 NetBird 状态与 Kubernetes 原有网络基线。

## Follow-up

- 持续核对 Operator CRD、默认副本、PDB 和官方 Kubernetes 文档。
- 每次 NetBird 客户端升级复测旧内核兼容模式是否仍有必要。
- 在监控文档中维护 Routing Peer、业务端口和 remote-write 的联合告警建议。
- 通过 `scripts/validate-docs.sh` 防止旧稳定版和不安全生产示例重新进入主线。
