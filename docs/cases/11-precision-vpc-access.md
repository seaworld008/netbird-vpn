# 案例 11：精确授权 VPC 内网资源

> 目标：客户端连接 NetBird 后，只能访问被授权的单台 VPC 主机或业务域名，而不是默认获得整个 VPC 网段权限。

## 1. 推荐模型

```text
用户设备 -> NetBird Policy -> Network Resource -> Routing Peer -> VPC 目标
```

初次上线优先为每台主机创建 `/32` 资源，例如：

```text
git.example.com       Domain
Git service current IP  203.0.113.20/32
Application A           10.20.30.11/32
Application B           10.20.30.12/32
```

`/32` 比直接授权 `10.20.0.0/16` 更容易审计和撤回。等主机数量和授权角色稳定后，再评估按业务子网合并。

## 2. 前置条件

- Routing Peer 位于目标 VPC，能够访问目标私网地址。
- Linux 已开启转发：`sysctl net.ipv4.ip_forward` 返回 `1`。
- 云安全组允许 Routing Peer 到目标端口。
- 若 Network 开启 Masquerade，目标看到的源地址是 Routing Peer 的 VPC 地址。
- 若关闭 Masquerade，VPC 路由表必须存在返回 NetBird overlay 网段的路由。

## 3. 命名和分组

建议把身份组、资源组和路由组分开：

```text
users-project-a
resources-project-a-git
resources-project-a-hosts
routing-peers-vpc-a
```

不要把用户和目标资源都塞进 `All`。已有 `All -> All` allow 策略时，新建精确策略不会形成限制，因为宽泛策略仍然允许访问。上线前必须审计并分阶段移除或缩小这类规则。

## 4. 创建 Routing Peer

为路由节点创建专用、短期或一次性 Setup Key，并自动加入 `routing-peers-vpc-a`。注册成功后撤销密钥并从运行环境删除。

```bash
sudo netbird up \
  --management-url https://netbird.example.com \
  --setup-key NBSETUP-EXAMPLE-REPLACE-ME
sudo netbird status
```

生产中建议使用独立 Compose 项目和持久卷，具体见 [Docker Compose 配置速查](../selfhosted/docker-compose-config-cheatsheet.md)。

## 5. 创建 Network 和资源

在 Dashboard 中：

1. 进入 `Networks`，创建 `vpc-a`。
2. 添加 Routing Peer，选择 `routing-peers-vpc-a`，Metric 使用默认值或团队统一值。
3. 开启 Masquerade，除非你已经设计回程路由。
4. 为每个允许目标创建 `IPv4` `/32` Network Resource。
5. 对依赖证书和域名的 HTTPS 服务，再创建 Domain Resource。
6. 把资源分别加入对应资源组。

路由节点高可用时可以添加第二个 Routing Peer，并用不同 metric 控制主备。两个节点必须都能访问相同目标，且安全组规则一致。

## 6. 最小权限策略

为不同业务资源创建独立 Policy：

| Policy | Source | Destination | 协议/端口 |
| --- | --- | --- | --- |
| `allow-project-a-git` | `users-project-a` | `resources-project-a-git` | TCP 443 |
| `allow-project-a-host` | `users-project-a` | `resources-project-a-hosts` | 需要的 TCP 端口 |

原则：

- 一个用户组只得到业务必需资源。
- SSH、数据库和 Web 使用不同资源组与 Policy。
- Setup Key 的 Auto Groups 只负责把设备放入身份组，不直接扩大资源权限。
- 一年期人用设备 Key 设置为 `Reusable=false`、`Usage limit=1`；一把 Key 只能注册一台设备。

## 7. 域名资源与 `/32` 兜底

Domain Resource 更符合 HTTPS 使用习惯，但客户端 DNS、缓存和其他 VPN 路由可能让当前解析 IP 没有走预期路径。验证时同时检查：

```powershell
Resolve-DnsName git.example.com
Get-NetRoute -AddressFamily IPv4 | Sort-Object DestinationPrefix
curl.exe -I https://git.example.com/
```

如果域名资源已启用，但客户端对当前解析地址没有形成可验证的 NetBird 路径，可以临时增加“当前解析 IP `/32`”作为伴随资源，同时保留 Domain Resource。

这是一种已观察到的兼容兜底，不是所有环境的必需配置。域名 IP 变化后，静态 `/32` 会失效，应通过 DNS 监控或自动化同步，不能长期靠人工猜测。

## 8. Windows 路由验收

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" status
& "$env:ProgramFiles\Netbird\netbird.exe" networks list
Get-NetAdapter | Where-Object InterfaceDescription -Match 'WireGuard|Wintun|NetBird'
Get-NetRoute -AddressFamily IPv4 |
  Where-Object DestinationPrefix -Match '/32$' |
  Sort-Object DestinationPrefix
Test-NetConnection 10.20.30.11 -Port 443
```

判断链路必须结合真实应用请求：

```powershell
curl.exe -vk --connect-timeout 10 https://10.20.30.11/
```

在请求前后查看 Routing Peer 状态或网络计数；传输量增长能证明请求经过 NetBird 数据平面。

## 9. 授权与拒绝测试

至少准备两台测试 Peer：

1. 授权 Peer 属于 `users-project-a`，应能访问允许的 TCP/HTTPS 服务。
2. 授权 Peer 访问未列入资源的同 VPC 主机，应失败。
3. 非授权 Peer 不属于该组，访问已列入资源的主机也应失败。
4. Dashboard 中临时停用 Policy 后，原授权访问应失败；恢复后重新成功。

只验证“授权用户能访问”无法证明最小权限有效。

## 10. 与其他 WireGuard VPN 共存

NetBird 可以与另一个 WireGuard VPN 同时运行，但必须检查路由重叠：

```powershell
Get-NetRoute -AddressFamily IPv4 |
  Sort-Object DestinationPrefix, RouteMetric |
  Format-Table DestinationPrefix, InterfaceAlias, RouteMetric
```

Windows 通常先按最长前缀匹配：NetBird 的目标 `/32` 会优先于另一个 VPN 的 `10.20.0.0/16`。若两边都有相同 `/32`，则接口和路由 metric 决定优先级。

上线前处理这些冲突：

- 另一个 VPN 的 full tunnel 或 kill switch。
- 两边相同的私网 CIDR。
- DNS 劫持或 DNS server 优先级。
- 同一目标的 `/32` 且另一个 VPN metric 更低。

最稳定的做法是让不同 VPN 负责不重叠的目标前缀，并为需要 NetBird 接管的主机保留明确 `/32`。

## 11. 排障顺序

1. `netbird status` 确认 Management 和 Signal 连接。
2. `netbird networks list` 确认 Network 已选择且资源可见。
3. 检查客户端目标路由和 DNS 解析。
4. 检查 Policy 是否被更宽的 allow 规则覆盖。
5. 检查 Routing Peer 在线、IP forwarding 和 Masquerade。
6. 检查云安全组、主机防火墙和应用监听端口。
7. 用 TCP/HTTPS 验证，不以 ICMP 作为唯一依据。

## 12. 回滚

1. 禁用新建 Policy。
2. 从 Network 移除新增资源。
3. 撤销用于注册的 Setup Key。
4. 必要时移除 Routing Peer，但保留其持久卷直到复盘完成。
5. 恢复变更前的宽泛策略时必须经过审批，并设置再次收敛的期限。

官方参考：

- https://docs.netbird.io/manage/networks
- https://docs.netbird.io/manage/networks/how-routing-peers-work
- https://docs.netbird.io/manage/networks/masquerade
- https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
