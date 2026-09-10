# 远程开发间歇超时：分层排查、整改与验收

## 1. 先定义问题

同一开发机经 NetBird 访问 Redis、RocketMQ、Nacos 时，记录来源 Peer、实际隧道
接口、目标 IP/端口、超时阈值和带时区的时间。将错误分成两类：

- TCP 建连超时：尚未建立连接，排查握手、ACL、转发、NAT 与目标接收路径。
- AUTH、PING、gRPC 或 MQ 请求超时：连接可能已经建立，继续检查应用响应、
  长连接重传、队列和中继外层，不能只用 `nc` 的成功结束排查。

以下示例用保留地址，不能照抄成实际目标：Redis `192.0.2.20:6383`，Nacos
`192.0.2.30:30848/31848`，MQ `198.51.100.20:9876`。MQ 还须检查 Topic 路由返回
的每个 Broker 地址，不能只检查最初填入的一个端口。

## 2. 拓扑和权限先只读核实

macOS：

```bash
netbird status --ipv4
netbird status -d
ifconfig utun100
route -n get 192.0.2.20
```

接口名称以现场为准，只有 IP、路由与 NetBird 状态一致才能确认归属。区分
Management、Signal、Relay 和 Routing Peer；它们可能同宿主机但在不同容器。

路由节点：

```bash
date -Is
ip route get 192.0.2.20
ip route get 192.0.2.30
ip rule
netbird status -d
ss -lun
```

确认 `/32` 与宽网段最终由谁转发、有无多个候选 Peer、Masquerade 和回程。公网
MQ 走隧道可能是有意的固定出口路由，必须核对资源及目标白名单后再评价；不要
为了更快直接改成私网地址或删除公网路由。

公网 Routing Peer 常见 WireGuard UDP 端口为 51820；TCP 大端口范围不包含 UDP。
`UDP 443` 由反向代理 HTTP/3 接收也不等于 Relay QUIC 已启用，见
[端口说明](firewall-and-hardening.md) 和 [QUIC 运维手册](relay-quic-runbook.md)。

## 3. 同时段的应用对照

至少持续 5–10 分钟，固定少量并发，不运行吞吐压测。分别从开发机、路由节点及
可访问的目标同网段探测，记录连接与响应时间、p50/p95/max、成功率和错误类型。
下面是一组 Redis 与 Nacos HTTP 的低负载基线；在终端隐藏输入密码，不写进脚本。

```python
import concurrent.futures as cf
import datetime, getpass, http.client, json, socket, time

password = getpass.getpass("Redis password (hidden): ")
targets = [("redis", "192.0.2.20", 6383), ("nacos", "192.0.2.30", 30848)]

def redis_reply(sock, *args):
    values = [a.encode() for a in args]
    sock.sendall(b"*" + str(len(values)).encode() + b"\r\n" + b"".join(
        b"$" + str(len(v)).encode() + b"\r\n" + v + b"\r\n" for v in values))
    data = b""
    while not data.endswith(b"\r\n"):
        part = sock.recv(1)
        if not part:
            raise EOFError("peer closed")
        data += part
        if len(data) > 1024:
            raise ValueError("unexpected response")
    return data

def probe(target):
    name, host, port = target
    result = {"time": datetime.datetime.now().astimezone().isoformat(), "target": name,
              "phase": "connect"}
    started = time.monotonic()
    try:
        with socket.create_connection((host, port), timeout=5) as sock:
            result["connect_ms"] = round((time.monotonic() - started) * 1000, 2)
            result["local"] = sock.getsockname()
            result["phase"] = "application"
            started = time.monotonic()
            if name == "redis":
                if redis_reply(sock, "AUTH", password) != b"+OK\r\n":
                    raise ValueError("AUTH failed")
                result["auth_ms"] = round((time.monotonic() - started) * 1000, 2)
                started = time.monotonic()
                if redis_reply(sock, "PING") != b"+PONG\r\n":
                    raise ValueError("PING failed")
            else:
                sock.sendall(("GET /nacos/v1/console/health/readiness HTTP/1.1\r\nHost: "
                              + host + "\r\nConnection: close\r\n\r\n").encode())
                response = http.client.HTTPResponse(sock)
                response.begin()
                response.read(1024)
                if response.status != 200:
                    raise ValueError("health status " + str(response.status))
            result["response_ms"] = round((time.monotonic() - started) * 1000, 2)
            result["status"] = "ok"
    except Exception as error:
        result["status"] = type(error).__name__
    return result

with cf.ThreadPoolExecutor(max_workers=2) as pool:
    for _ in range(36):
        tick = time.monotonic()
        for row in pool.map(probe, targets):
            print(json.dumps(row), flush=True)
        time.sleep(max(0, 10 - (time.monotonic() - tick)))
```

Redis 此处 `response_ms` 为认证后的 PING；Nacos 为 HTTP 响应。无凭据时可单独
发 PING 并记录 NOAUTH，但只能说明协议有响应，不是认证验收。长连接测试应复用
原 socket，每30秒 PING，而不是把重复新建连接称为长连接。

RocketMQ 使用既有 CLI 和授权的只读操作，例如在对应安装目录执行：

```bash
sh bin/mqadmin topicRoute -n 198.51.100.20:9876 -t EXAMPLE_TOPIC
sh bin/mqadmin brokerStatus -b 198.51.100.20:10931
sh bin/mqadmin brokerStatus -b 198.51.100.20:10941
```

不要生产或消费测试消息。需要 ACL 时通过已有安全凭据配置，不把密钥放进命令
回显。Nacos gRPC 要用当前官方客户端的 `ServerCheckRequest` 验证服务响应；
TCP 建连或 HTTP/2 SETTINGS 不能代替 gRPC 健康响应。该请求的协议依据见文末。

## 4. 安全的定向包头与计数

同步观察 Router 隧道入口、目标出口、目标主机，必要时进入目标容器网络空间。
只采集指定地址与端口，文件仅在受控本地保存，不上传。

Linux RAW-IP 的 `wt0` 可使用40字节截断，以太网接口可使用54字节截断，保证
不会读取最小 IPv4/TCP 头之后的负载；TCP options 可能显示截断。必须先确认链路
类型，其他封装不能机械使用这两个数值。

```bash
timeout 90 tcpdump -p -nn -tttt -S -l -s 40 -i wt0 \
  'ip and tcp and host 100.100.1.10 and (port 6383 or port 30848 or port 31848)'
timeout 90 tcpdump -p -nn -tttt -S -l -s 54 -i eth0 \
  'ip and tcp and host 192.0.2.20 and port 6383'
```

以上刻意只处理 IPv4；IPv6、VLAN及其他链路应重新确定包头长度。不要用固定
`-s 96` 或 `-s 128` 就声称不包含 AUTH：短包头后面仍可能被截入密码。只关心
握手时，也可用过滤表达式要求 TCP payload 长度为0。不要添加 `-A`/`-X`。

按源/目标、端口、sequence/ACK 和时间关联 NAT 前后；TCP 重传/乱序可能产生
重复包，不能把它们当不同请求。跨主机时间差须考虑时钟偏差。外层 TLS/QUIC
只能看到加密传输元数据，不能据此知道具体哪条 SQL、AUTH 或 MQ 内容。

Caddy/Relay/Redis 在独立命名空间时，在真正拥有 socket 的空间采集计数：

```bash
APP_PID=$(docker inspect -f '{{.State.Pid}}' example-container)
sudo nsenter -t "$APP_PID" -n ss -tin
sudo nsenter -t "$APP_PID" -n nstat -az
conntrack -S
ip -s link show eth0
tc -s qdisc show dev eth0
```

先记录基线，再记录同一窗口的增量；不要混用宿主机和容器的 nstat。重传字节
占比不是精确线路丢包率；服务器响应进入隧道后到客户端 ACK 的延迟，还包含
客户端处理、延迟 ACK 和返回链路时间。

## 5. 两类已验证的故障模式

### 5.1 旧内核与 NAT 时间戳

若失败 SYN 到达 Redis 容器但没有 SYN-ACK，且 PAWSPassive 与 ListenDrops
同时增加，检查旧 Linux 的 `tcp_tw_recycle`。它与 NAT、按连接随机化时间戳
不兼容。先有抓包/增量证据，再获准做单项修正：

```bash
sysctl net.ipv4.tcp_tw_recycle
# 以下是获准后的修改，不是只读诊断命令：
sudo sysctl -w net.ipv4.tcp_tw_recycle=0
```

修改前备份原运行值和实际 sysctl 来源文件，持久化只改这一项。新内核可能已移除
该参数，不要为“整齐”创建无效项或统一改 tcp_tw_reuse/tcp_timestamps。无需因此
重启 Redis、提高 maxclients 或升级整台服务器。回滚恢复该单项原值可能复发，
仅在明确需要时执行，不整份回灌防火墙。

曾实测单项修正后客户端从14/40恢复40/40，PAWS增量归零；同批其他主机原本
关闭或已经不支持该参数，没有批量调整。后续故障仍须重新检查，不能永久套用根因。

### 5.2 中继外层 TCP 重传

如果 Router 内部转发快、直接应用响应稳定，但多个目标的响应进入隧道后都
延后确认，且同一外层 WS TCP socket 重传持续增加，优先调查这段共同路径。
WS 正常可用不意味着在高丢包环境下仍适合所有交互式开发请求。

核对实际 WireGuard UDP 直连入口、QUIC 监听、云端带宽及客户端网络。只发现
Relayed、宽/窄路由并存或一个累计错误值，均不足以定责。`peer exited gracefully`
也不证明人为断开；应关联客户端操作与同一时刻的控制/中继日志。

## 6. 稳定远程开发验收

1. 同一客户端、同一网络、同一目标与阈值，记录 P2P/Relayed 和 quic/ws。
2. Redis两条长连接30分钟；再做3轮各15条并发 AUTH+PING，轮间留间隔。
3. 同时低负载探测 Nacos HTTP/gRPC、NameServer 和路由返回的全部 Broker。
4. 在对应窗口启动 Gateway、业务服务与依赖服务，检查池初始化、注册、监听和健康。
5. 授权设备真实访问成功，非授权设备仍不可通过 NetBird访问；缺少设备时明确未实测。
6. 目标可设为0超时、p95低于应用超时预算，具体阈值按业务商定；不能仅放大超时
   参数掩盖抖动，也不能把不同来源/不同时段的结果当作同条件性能改善。

多路由节点升级采用“固定镜像、身份备份、单实例、业务与监控回归、下一实例”，
参见 [Kubernetes 手册](kubernetes-routing-peer-runbook.md)。没有外网拉取条件时，
在可信机器取得已核验镜像，校验归档SHA256及导入后的image ID；不得改成浮动
标签或为一次升级扩大镜像仓库权限。

## 7. 官方参考

- [资源连通性](https://docs.netbird.io/help/troubleshooting-resource-connectivity)
- [中继排障](https://docs.netbird.io/help/troubleshooting-relayed-connections)
- [内核移除 tcp_tw_recycle 的原因](https://github.com/torvalds/linux/commit/4396e46187ca5070219b81773c4e65088dac50cc)
- [RocketMQ 请求代码](https://github.com/apache/rocketmq/blob/rocketmq-all-5.1.4/remoting/src/main/java/org/apache/rocketmq/remoting/protocol/RequestCode.java)
- [Nacos ServerCheck](https://github.com/alibaba/nacos/blob/2.2.0/core/src/main/java/com/alibaba/nacos/core/remote/grpc/GrpcRequestAcceptor.java)
