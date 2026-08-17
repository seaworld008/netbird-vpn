# ADR-004: 定向公网出口使用隔离的单节点 Routing Peer

## Status

Accepted

## Date

2026-08-17

## Context

部分白名单系统只有少量公网 IP 或域名需要从获准的固定公网 IP 访问。若客户端
使用全局 Exit Node，会把不相关的互联网流量也转交该节点，扩大性能、隐私和
故障影响范围。

固定出口可能位于同时运行 Kubernetes、Docker 业务和既有 WireGuard 容器的
Linux 节点。旧内核、legacy iptables / nftables 混用环境中，宿主机直接运行
另一个 VPN 客户端或使用 host 网络的高权限容器，可能改变宿主机路由和防火墙，
影响 CNI、kube-proxy、业务 Pod 或现有 WireGuard。

普通 Kubernetes Routing Peer 的双节点高可用模型也不能直接套用：如果第二个
节点拥有不同公网出口，而目标只放行一个 IP，故障切换反而会造成确定性中断。

## Decision

1. 少量公网目标使用 `Networks` 和精确 Network Resource，不使用默认路由或
   全局 Exit Node。
2. IP `/32` 和 Domain Resource 放入两个独立 Network，分别绑定专用资源组、
   Policy 和同一个专用 Routing Peer 组。
3. Routing Peer 使用单副本 `Deployment`、`Recreate` 策略和精确节点亲和性，
   固定在具备获准公网出口的节点。
4. Pod 不使用 `hostNetwork`、`hostPort`、宿主机 PID 或 IPC；使用
   `NB_USE_NETSTACK_MODE=true` 把隧道数据面留在 Pod 网络命名空间。
5. 使用场景专属、权限为 `0700` 的持久身份目录；不得与宿主机 NetBird、其他
   Routing Peer 或并发 Pod 共享 `/var/lib/netbird`。
6. Setup Key 设为短有效期、一次使用并自动加入专用 Routing Peer 组。首次注册
   后撤销 Key、删除 Kubernetes Secret，并通过 Pod 重建验证身份复用。
7. Masquerade 默认开启；来源客户端组和目标资源组使用真实业务端口的最小权限
   Policy，不建立 `All -> All`。
8. 上线前先证明普通 Pod 已从预期公网 IP 出口；上线后同时验证授权客户端、
   非授权客户端、Routing Peer 计数、目标侧来源 IP 和宿主机/集群无回归。
9. 故障时先把本 Deployment 缩容为零，不先重启 Docker、已有 WireGuard、CNI、
   kube-proxy、业务 Pod 或节点。
10. 只有所有候选节点共享获准出口，或目标已放行全部候选出口 IP 时，才允许增加
    第二个独立 Routing Peer。

## Alternatives Considered

### 在宿主机直接安装第二个 VPN 客户端

组件更少，但会让 NetBird 与已有 WireGuard、Docker、CNI 和宿主机 netfilter
共享故障域。对于已出现过系统网络回归的多用途节点，不采用。

### 使用 host 网络的容器或 Pod

端口和路由路径直观，但 Userspace Netstack 不能抵消 host 网络命名空间带来的
耦合。既有 WireGuard 还可能占用相同 UDP 端口，故不作为生产默认方案。

### 创建全局 Exit Node

配置简单，但会接管所有互联网流量，超出“仅指定 IP 或域名”的授权目标，故不
采用。

### 复用已有通用 Kubernetes Routing Peer

可以减少一个 Peer，但会把不同业务、出口、资源和回滚边界混合。专用白名单
场景需要能独立停用和审计，故不采用。

### Deployment 直接扩成多个副本

同一身份目录不能被多个在线 Peer 共享；不同节点也可能产生不同公网出口。只有
满足决策第 10 条并为每个 Peer 准备独立身份时，才可另行设计高可用。

### 使用独立 VM 作为 Routing Peer

隔离更强，通常是有可用 VM 时的优先选项。本决策处理的是固定出口已经位于
Kubernetes 节点且不能立即迁移的场景。

## Consequences

- 只有指定资源走固定出口，客户端其他互联网流量保持原路径。
- Routing Peer 可被独立停止，已有 WireGuard 和 Kubernetes 网络无需重启。
- 单节点出口的可用性受该节点影响，但不会用错误公网 IP 做无效故障切换。
- Userspace 数据面可能增加 CPU 消耗，需按实际吞吐监控。
- Domain Resource 依赖 Routing Peer DNS Resolution，必须单独验证解析、TCP、
  SNAT 和策略，不能只验证 DNS。
- 公网目标可能从客户端本地互联网直接可达，因此非授权验收必须看 Network、
  路由、Routing Peer 计数和目标侧来源，不能只看请求成功或失败。

## Follow-up

- 持续核对 NetBird Domain Resource 和 Routing Peer DNS Resolution 的上游行为。
- 每次 NetBird 客户端升级复测 Userspace、域名解析、固定出口和同机 WireGuard。
- 当固定出口迁移到独立 VM 或统一 NAT Gateway 后，重新评估单节点约束。
- 由 `scripts/validate-docs.sh` 阻止 Kubernetes NetBird 生产 YAML 使用 host 网络，
  并检查定向出口案例没有在代码块中配置默认路由。

## Related Decisions

- [ADR-002：生产环境固定镜像版本并隔离 Routing Peer](./ADR-002-pinned-images-and-routing-peer-isolation.md)
- [ADR-003：Kubernetes Routing Peer 使用分阶段发布和兼容数据面](./ADR-003-kubernetes-routing-peer-safety-model.md)
