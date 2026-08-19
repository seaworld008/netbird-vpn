# 验证与回滚

## 1. 验收矩阵

为每条流量契约至少准备一个授权来源和一个非授权来源。记录时间、来源 Peer、目标、命令、结果和预期。

| 层级 | 验证 | 通过标准 |
| --- | --- | --- |
| 控制面 | Dashboard / API 对象详情 | 名称、ID、成员、依赖、启用状态和数量正确 |
| Peer | `netbird status -d` / API peers | Management、Signal、Relay 正常，Peer 身份和组正确 |
| 资源分发 | Networks / routes / client status | 预期 Resource 和路由已收敛，不出现意外默认路由 |
| 客户端路由 | Windows / macOS / Linux 路由表 | 目标最长前缀选择 NetBird，其他默认流量保持原路径 |
| DNS | 授权端和 Routing Peer 分别解析 | 结果、TTL、A / AAAA、SNI 符合预期 |
| 真实协议 | `curl`、`nc`、SSH、数据库客户端、`kubectl` | 正确端口和应用握手成功；HTTP `200/3xx/401/403` 按场景判断 |
| 拒绝 | 非授权 Peer 重复真实协议 | 没有 NetBird Policy / Route 赋权；记录本地公网直连例外 |
| 数据面 | 请求前后 Peer 详情 / counters | 预期 Routing Peer 接收和发送计数增长 |
| SNAT / 回程 | 目标日志、访问日志、抓包 | 目标看到设计中的内网或公网来源，返回路径正确 |
| 无回归 | 业务容器、Pod、Node、监控 | DNS/TCP/外联/remote-write 正常，重启次数和路由规则无意外变化 |
| 凭据 | Key / Secret / 环境 / 文件复核 | 临时 Key 已撤销或移除，Peer 仍用持久身份重建 |

`Connected`、Pod Ready、`status --check ready`、DNS 成功和 `ping` 都只能证明局部状态，不可单独作为完成证据。Peer 刚重建后可能先 Ready，Networks 和路由稍后才收敛；应等待并复查完整状态。

## 2. 授权测试

1. 确认来源 Peer 确实属于目标来源组，且没有其他宽策略提供同一路径。
2. 记录请求前 Routing Peer 计数。
3. 查看客户端路由并发起真实协议请求。
4. 记录应用响应、TLS / SSH / 数据库握手或 Kubernetes API 结果。
5. 记录请求后计数和目标侧来源地址。
6. Domain Resource 还需确认请求使用域名而不是直接 IP。

## 3. 非授权测试

1. 使用明确不在来源组、且没有其他访问策略的 Peer。
2. 检查它是否收到 NetBird Resource / Route，再发真实协议请求。
3. 私网目标应因缺少路由或 Policy 失败。
4. 公网目标可能经本地互联网成功；此时通过客户端路由、Routing Peer 计数不增长和目标侧来源 IP 证明请求没有走 NetBird，而不是要求请求必须失败。
5. 检查默认 `All` Policy、旧 Policy、legacy Route 和重叠组是否形成旁路。

## 4. Kubernetes 无回归

至少覆盖：

- Node、CNI、kube-proxy、CoreDNS 健康。
- Pod IP、ClusterIP、远端 NodePort 的真实 TCP。
- 普通 Pod DNS 和外联。
- 监控 remote-write 成功数、错误数、队列或最近错误日志。
- 同机 Docker / WireGuard 和宿主机路由、策略路由、iptables / nftables 对比。
- Routing Peer Pod `RestartCount` 和独立身份。

单节点失败时先只隔离该 Peer；保留另一个 Peer 和业务工作负载。定向出口单副本则只把该 Deployment 缩容为零。

## 5. Standalone 无回归

- 容器内 `Interface type: Userspace`，Management、Signal、Relay 正常。
- 业务容器内部 DNS 和真实 TCP 与基线一致。
- 业务容器 `StartedAt`、`RestartCount` 未变。
- 授权客户端访问私网 Resource，不用 Routing Peer 公网 IP 代替。
- Routing Peer 计数增长；必要时在 bridge、宿主机出口或目标侧抓包。

故障时先只停止 Routing Peer 并观察业务是否无需重启即可恢复。不要先清空防火墙或重启 Docker。

## 6. 停止条件

出现以下任一情况，停止扩大范围并进入隔离或回滚：

- 实际对象、租户或主机与预览不一致。
- 发现未盘点的共享依赖、同名对象或 CIDR 重叠。
- 授权测试未证明预期路径，或非授权端获得意外 NetBird 路由。
- 目标侧来源地址错误，可能破坏白名单或回程。
- 业务容器、Pod 外联、CNI、kube-proxy、监控或现有 VPN 出现回归。
- Peer 身份改变、重复注册、多个实例共享身份目录。
- API 返回权限、schema、tenant 或速率限制错误，重读状态后仍无法安全确定写入结果。

## 7. 回滚顺序

优先撤回最小、最新、可疑的数据面组件：

1. 停止扩大成员、第二 Peer 或后续对象。
2. 禁用本次新 Policy 或把测试来源移出，不先删除证据。
3. 停止 / 缩容本次 Routing Peer，观察原业务是否恢复。
4. 恢复本次修改前的 Network / Resource / Route / Masquerade 配置。
5. 只有本次确实修改了主机持久配置时，才按保存的差异回滚；不整份覆盖正在运行的 Kubernetes netfilter。
6. 恢复原固定镜像或 Compose / YAML，保持身份目录和卷不变。
7. 重新执行授权、拒绝、数据面和无回归矩阵。

回滚后再次盘点，确认没有临时 `100.64.0.0/10` 大路由、额外 NAT、测试 Policy、Setup Key、Secret 或离线重复 Peer 遗留。
