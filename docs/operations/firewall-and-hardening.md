# 阿里云安全组与端口加固（可直接复用）

## 一、基础端口

```text
TCP 80   (HTTP/ACME)
TCP 443  (HTTPS/gRPC 与 Relay WebSocket)
UDP 3478 (现代部署的 STUN)
UDP 443  (Relay QUIC；仅在部署明确发布并通告该端点时开放)
```

端口作用说明：

- `80/tcp`：给 Let's Encrypt 或反向代理做证书申请、HTTP 跳转。
- `443/tcp`：Dashboard、Management API/gRPC、Signal 和 Relay WebSocket 的
  共享入口。WebSocket Relay 也是 QUIC 不通时的 TCP 回退路径。
- `3478/udp`：现代 quickstart 中由原生 Relay 的嵌入式 STUN 提供，用来发现
  NAT 映射并提高直连概率。
- `443/udp`：原生 Relay 的 QUIC 传输。只有 Compose、负载均衡和 Relay 公告
  地址都明确使用 UDP 443 时才开放；官方脚本生成结果没有发布该端口时，不要只
  改安全组假装启用了 QUIC。

NetBird 客户端会并行尝试原生 Relay 的 QUIC 与 WebSocket。`443/udp` 被阻断时
可以回退到 `443/tcp` 的 WebSocket Relay，但延迟和吞吐可能变化；如果所有 UDP
都被阻断，还会失去 STUN 辅助和多数直接 P2P 路径。上线验证必须看
`netbird status -d` 的实际连接路径，不能只看端口规则存在。

TURN / Coturn 是 legacy 兼容回退，不是现代 quickstart 的默认主线。新部署不要
默认开放 Coturn 的 `49152-65535/udp` 大端口段；只有保留 legacy Coturn、完成
风险评估并按对应版本文档配置时才开放。

## 二、本机防火墙示例（可选）

不要在远程 SSH 会话中直接复制一组公网放行后就执行 `ufw enable`。先确认实际
SSH 端口和当前管理出口地址，准备云厂商控制台或串口等带外入口，并保持第二条
SSH 会话在线。下面的管理来源必须缩小到运维出口 `/32` 或受控管理网段，不能
为了省事填 `0.0.0.0/0`：

```bash
set -euo pipefail

: "${ADMIN_CIDR:?set ADMIN_CIDR, for example 198.51.100.10/32}"
: "${SSH_PORT:?set the actual SSH port, for example 22}"

UFW_CHANGE_DIR="$HOME/netbird-ufw-change-$(date +%Y%m%d-%H%M%S)"
install -d -m 700 "$UFW_CHANGE_DIR"
sudo ufw status numbered | tee "$UFW_CHANGE_DIR/status.before.txt"
sudo ufw show added | tee "$UFW_CHANGE_DIR/rules.before.txt"

sudo ufw allow from "$ADMIN_CIDR" to any port "$SSH_PORT" proto tcp \
  comment 'NetBird change SSH management'
sudo ufw allow 80/tcp comment 'NetBird change HTTP ACME'
sudo ufw allow 443/tcp comment 'NetBird change HTTPS and Relay WebSocket'
sudo ufw allow 3478/udp comment 'NetBird change STUN'
sudo ufw show added | tee "$UFW_CHANGE_DIR/rules.after.txt"
sudo ufw status numbered | tee "$UFW_CHANGE_DIR/status.after-rules.txt"
```

如果部署清单确认 Relay 对外发布 QUIC `443/udp`，再执行：

```bash
set -euo pipefail

sudo ufw allow 443/udp comment 'NetBird change Relay QUIC'
```

先确认第二条现有 SSH 会话保持在线，并确认带外控制台可用；然后从原会话执行
`sudo ufw enable`，但不要关闭这两条旧会话。启用后新开第三条 SSH 连接，确认
管理来源规则确实命中，再验证 Dashboard、Management、Signal、Relay 和真实
Peer 连接。

若新连接或业务链路异常，先比较 before / after 快照，并用
`sudo ufw status numbered` 确认本次新增且带 `NetBird change` 注释的规则；无论
变更前是否 active，都要按编号从大到小执行 `sudo ufw delete NUMBER`，避免规则
留在持久配置中。然后查看 `$UFW_CHANGE_DIR/status.before.txt`：原来 inactive
才执行 `sudo ufw disable`，原来 active 则保持防火墙开启并执行
`sudo ufw reload`。如果无法唯一识别本次规则，保持旧会话和带外入口，不要猜测
删除或关闭整个 UFW，转入人工变更回滚。

> `443/tcp` 常同时承载远程 Peer 的控制面、Signal、Relay WebSocket 和可能的
> 公网 Reverse Proxy 服务。不要在共享入口上直接套办公网白名单，否则会同时
> 切断不在白名单内的 Peer 和外部用户。需要限制管理界面时，应先把管理入口与
> Peer/代理入口分离，再在独立入口实施来源限制和身份认证。

## 三、阿里云安全组配置示例

适用于绝大多数阿里云 ECS 新手场景：

| 方向 | 优先级 | 协议类型 | 端口范围 | 授权对象 | 备注 |
| --- | --- | --- | --- | --- | --- |
| 入方向 | 1 | TCP | 80/80 | `0.0.0.0/0` | NetBird HTTP/证书 |
| 入方向 | 1 | TCP | 443/443 | `0.0.0.0/0` | HTTPS/gRPC、Relay WebSocket |
| 入方向 | 1 | UDP | 3478/3478 | `0.0.0.0/0` | NetBird STUN |
| 入方向 | 1 | UDP | 443/443 | `0.0.0.0/0` | 条件项：Relay QUIC |

填写说明：

1. 在阿里云控制台进入 ECS 实例对应的“安全组”。
2. 选择“入方向”。
3. 授权对象公网开放时填 `0.0.0.0/0`。
4. `443/udp` 只在应用配置、容器端口、负载均衡和 Relay 公告地址都启用 QUIC
   时添加。
5. 如果 `443/tcp` 是共享入口，不要把它缩成只允许办公出口 IP；先完成入口
   拆分。
6. 添加完成后，再检查系统本机的 `ufw` 或其他防火墙是否也已放行。

## 四、安全基线建议

- 强制控制台管理员启用双因子
- 对外日志集中采集（控制面、客户端、网关）
- 变更必须走审批流程（尤其是策略变更）
- 对关键脚本与证书文件设置严格权限（root 归属）

## 五、路由节点安全组怎么开

路由节点不是 NetBird 服务端，它通常放在办公室、VPC、K8S 同网段或多云内网里。

最小原则：

- 路由节点出方向允许访问 Management、Signal 和 Relay 的 `443/tcp`。
- 允许访问已配置 STUN 端点的 `3478/udp`。
- 如果已通告 QUIC Relay，允许访问对应端点的 `443/udp`；阻断时确认客户端确实
  回退到 WebSocket，而不是把 `Connected` 当成数据面验证。
- 路由节点到目标资源的业务端口必须放通。
- 不要把路由节点 SSH 直接开给公网。

示例：办公室路由节点 `10.20.0.10` 要访问 GitLab、Jenkins、MySQL：

| 目标 | 协议 | 端口 | 来源 |
| --- | --- | --- | --- |
| `10.20.10.20` GitLab | TCP | `443` | `10.20.0.10/32` |
| `10.20.10.30` Jenkins | TCP | `8443` | `10.20.0.10/32` |
| `10.20.30.15` MySQL | TCP | `3306` | `10.20.0.10/32` |

如果开启 Masquerade，后端业务系统看到的来源通常就是路由节点内网 IP，所以业务系统白名单也优先写：

```text
10.20.0.10/32
```

## 六、验证命令

服务端公网端口：

```bash
curl -I https://netbird.example.com
```

STUN 和 QUIC 都不能用 TCP 探测证明可用。先确认安全组、本机防火墙、容器端口
和 Relay 公告配置一致，再从客户端看详细连接路径：

```bash
netbird status -d
```

验证时至少区分：

- 直连是否建立；没有直连时是否进入原生 Relay。
- Relay 使用 QUIC 还是 `443/tcp` WebSocket 回退。
- 限制 UDP 的网络是否仍能通过 WebSocket 访问真实 TCP/HTTPS 资源。
- 没有部署 legacy Coturn 时，是否仍残留不必要的 TURN 大端口段。

路由节点到目标资源：

```bash
nc -vz 10.20.10.20 443
nc -vz 10.20.10.30 8443
nc -vz 10.20.30.15 3306
```

客户端到目标资源：

```bash
netbird status
curl -k -I https://10.20.10.20
nc -vz 10.20.20.10 22
```

如果路由节点能访问目标，但客户端不能访问目标，优先检查 NetBird 的资源组和访问策略。

## 七、官方参考

- Self-hosted Quickstart：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- Ports & Firewalls：https://docs.netbird.io/about-netbird/ports-and-firewalls
- NAT 与连接路径：https://docs.netbird.io/about-netbird/understanding-nat-and-connectivity
- Coturn 到嵌入式 STUN 迁移：https://docs.netbird.io/selfhosted/migration/coturn-to-stun-migration
