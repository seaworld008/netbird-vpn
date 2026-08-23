# 网络设计规则

## 1. 对象关系

把配置设计为清晰的依赖图：

```text
用户 / 设备 / 工作负载
  -> 来源 Group
  -> ALLOW Policy（方向、协议、端口、Posture）
  -> 资源 Group
  -> Network Resource（IP / Range / Domain）
  -> Network
  -> Routing Peer Group
  -> 独立 Routing Peer 身份
  -> 目标服务
```

一个 Group 可以有多种依赖，因此删除前必须查看 Users、Peers、Policies、Network Resources、Routes、Setup Keys 和 DNS。Policy 只有允许语义，不依赖规则顺序实现拒绝。

## 2. 命名和职责

名称应同时表达环境、业务、角色和方向，避免 `test1`、`vpn-access`、`new-policy` 等无法审计的名称。

推荐模式：

```text
<env>-<team>-clients
<env>-<site>-routing-peers
<env>-<service>-resources
<env>-<team>-to-<service>-<protocol>-<port>
<env>-<site>-router-01
```

示例只使用脱敏名称：

```text
prod-finance-clients
prod-hq-routing-peers
prod-erp-resources
prod-finance-to-erp-tcp-443
prod-hq-router-01
```

来源组只放访问者，Routing Peer 组只放路由节点，资源组只承载 Resource。用户组和设备组是否合并取决于身份源和审计目标，但人员身份不得用共享 Setup Key 替代。

## 3. 资源粒度

按最小可管理单元选择：

| 目标 | 优先类型 | 注意点 |
| --- | --- | --- |
| 单台服务 | `/32` IP | 最清晰，适合白名单和数据库 |
| 少量相邻主机 | 多个 `/32` | 先精确，再根据证据扩网段 |
| 明确业务子网 | IP Range | 不要把整个 VPC 当成第一步 |
| HTTPS / 证书依赖域名 | Domain | 单独验证 Routing Peer DNS Resolution |
| 所有互联网流量 | Exit Node / 默认路由 | 必须是用户明确目标 |
| 少量公网白名单目标 | 精确 `/32` / Domain | 不使用默认路由 |

客户端 LAN、其他 VPN、Docker 子网、VPC、Pod CIDR、Service CIDR 和 NetBird Overlay 都要检查重叠。路由选择遵循最长前缀；远端 `/16` 可能输给客户端本地 `/24`。优先换非重叠地址或收紧到 `/32`，再用客户端路由表和计数证明实际路径。

Domain 与覆盖其解析 IP 的宽 IP Range 不应放在同一 Network，否则资源策略可能相互覆盖。域名变化还要考虑 TTL、多个 A / AAAA 记录、证书 SNI 和目标端口。

## 4. Policy 设计

- 从真实业务协议反推端口，不用 `ping` 代替 TCP / UDP / HTTPS。
- 数据库、SSH、Web、Kubernetes API 和监控分别授权。
- Public API 的 `ports` 与 `port_ranges` 不能同时出现在同一条规则中，创建和更新都会拒绝这种请求。若业务同时需要单端口与区间，统一使用 `port_ranges`，例如 `22` 写成 `{"start": 22, "end": 22}`，`8000-8100` 写成 `{"start": 8000, "end": 8100}`。
- 双向流量只在应用确实需要时开启；不要因为排障方便就设成全双向。
- 默认组 `All` 不能删除且自动包含所有 Peer，不用于生产最小权限来源。
- 上线前准备一台明确不在来源组的 Peer 做拒绝测试。
- Posture Check 先在测试组验证，确认客户端平台和版本能回报所需属性，再扩大范围。

## 5. Masquerade 和来源地址

默认开启 Masquerade：目标看到 Routing Peer 所在网络的地址，通常无需给 NetBird Overlay 添加回程路由。

只有业务确实需要真实客户端源地址时才关闭，并同时完成：

1. 目标网络到 NetBird Overlay 的回程路由。
2. 云安全组、主机防火墙和应用白名单调整。
3. 双向路由和非对称路径验证。
4. 目标侧实际来源地址观察。

固定公网出口还要区分 Routing Peer Pod / 容器的 SNAT、宿主机 / 云 NAT 的 SNAT 和目标看到的最终公网 IP。

## 6. Routing Peer 选择

| 场景 | 推荐 |
| --- | --- |
| 少量 Kubernetes Service | 官方 Kubernetes Operator |
| 只访问 Kubernetes API 或大量 VPC 服务 | 集群同 VPC 的独立 VM |
| 旧集群需要 Pod / Service CIDR | 受控节点手工 Peer，单节点先行 |
| 多用途 Docker 主机 | 独立 Compose、bridge、Userspace、独立身份 |
| 少量公网目标走固定节点 | 单副本 `Recreate`、精确节点、独立 Network / Peer |
| 所有互联网流量统一出口 | 专用 Exit Node，明确默认路由影响 |

Routing Peer 是数据面组件。高可用不是复制同一 `/var/lib/netbird`，而是多个独立 Peer 身份加入同一 Routing Peer 组。固定公网白名单只有在候选 Peer 共享获准出口时才能做多 Peer。

## 7. Setup Key 和身份

- 普通长期设备：每台一个有名称的 One-off Key，控制台按 `usage_limit=1` 创建，或让人员通过 SSO 登录。
- 两个受控手工 Peer 的一次性批量注册：可用短有效期、usage limit=2 的 Reusable Key；完成后撤销。
- 自动弹性工作负载：优先 Operator、外部 Secret 管理或明确的 Ephemeral 模型，不保留无限次 Key。
- One-off 是单次使用类型，不是“可填写次数的一次性批次”。NetBird v0.77.1 起，Public API 对 One-off 的 `usage_limit > 1` 返回 HTTP `422`；兼容调用仍可发送 `0` 表示未指定，但这不会把 One-off 变成可重复使用。需要注册多台设备时必须选择 Reusable，并把上限设为计划设备数。
- 已使用的 One-off Key 不能恢复明文或重新命名；审计依赖预先命名、Peer 资产名和事件记录。
- Key 过期或撤销不会让已注册 Peer 下线；持久身份目录才是重建和灾备对象。

## 8. 常见目标模型

### 远程办公替代传统 VPN

按系统拆 Resource 和 Policy，不给员工整个办公网段。数据库读者、运维 SSH 和普通 Web 分组。

### 敏感白名单系统

每个系统 `/32` 或 Domain，后端白名单默认加入 Routing Peer 地址；授权和非授权各测一次。

### 多云

每个 VPC / 区域独立 Routing Peer 和 Network，先单向单端口，再逐路径扩展。重叠 CIDR 未解决前不上线。

### 团队配置收敛

盘点旧新组、策略、Key 和 Peer；先建目标组并迁移成员，建立并验证统一 Policy，再按授权删除旧路径。最终按精确对象数量和依赖复核，不以“删除成功”提示代替。

### 定向公网出口

目标 `/32` 与 Domain 分离 Network，使用同一个专用 Routing Peer 组但不同资源组和 Policy。客户端其他默认流量保持原路径；验收必须观察目标侧公网来源和 Routing Peer 计数。
