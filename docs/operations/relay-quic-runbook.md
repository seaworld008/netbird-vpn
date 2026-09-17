# Relay QUIC、WebSocket 与稳定远程开发

> 新装继续使用官方 `getting-started.sh` 生成结果。本页主要处理已有独立 Relay +
> Caddy 的存量部署，不是另一套安装模板。组合容器的配置必须按其当前官方文档
> 核对，不能原样套用独立 Relay 的环境变量。

## 1. 最终效果与边界

- 能直连的 Peer 使用 P2P；需要中继时可使用 QUIC，并保留 WebSocket 回退。
- 客户端访问资源的 Policy、Routing Peer、Masquerade 和固定出口保持原边界。
- 同一个 Relay 进程处理 QUIC 与 WebSocket，不把两个协议分流到互不共享会话的实例。
- 文件证书续期会校验并只重载 Relay；失败不重启数据库或整个 Compose 项目。

QUIC 不会修复所有物理丢包、办公网拥塞或客户端调度问题。也不能把 P2P 下的应用
测试结果写成 QUIC 中继性能测试。上线记录必须说明实际走过的路径。

## 2. 端口与示例参数

| 参数 | 示例 | 说明 |
| --- | --- | --- |
| 域名 | `netbird.example.com` | 改成自己的有效域名 |
| 目录 | `/opt/netbird` | 原官方生成目录 |
| Relay 镜像 | `netbirdio/relay:0.78.1` | 与 Management/Signal 固定版本一致 |
| Caddy 镜像 | `caddy:2.11.4` | 本次实测版本；原部署按兼容性评估 |
| TCP 443 | Caddy HTTPS / WebSocket | 保留共享管理入口 |
| UDP 443 | Relay QUIC | 不再交给 Caddy HTTP/3 |
| Relay 内部 33080 | TLS/WS TCP + QUIC UDP | 同一进程的两个监听 |
| Routing Peer UDP | 常见 51820 | 以实际监听为准；与 Relay 是不同用途 |

`TCP 49152–65535` 不会放行 `UDP 51820`。控制面与 Routing Peer 可以同机，
也可以分离；只有真正的公网 Routing Peer 才需要相应直连入站规则。

## 3. 变更前盘点

记录服务名、镜像 digest、部署路径、端口归属、身份与业务基线。不要输出全部
容器环境变量或管理配置，其中可能包含密钥。

```bash
date -Is
docker compose ps
docker compose config --images
docker inspect "$(docker compose ps -q relay)" --format '{{json .NetworkSettings.Ports}}'
ss -lun
netbird status -d
```

上面的 `relay` 是 Compose 服务名，必须按实际项目修改。重点确认：

1. Relay 是否只有 TCP 监听，是否出现 `Not starting QUIC listener`。
2. UDP 443 是否被 Caddy 的 HTTP/3 占用；安全组放行不等于 Relay 已启用。
3. 证书域名、有效期、私钥匹配，且应用能读取；不要把私钥复制进 Git。
4. 共享 TCP 443 上有哪些控制和身份连接；修改映射会重建 Caddy，不能承诺零中断。
5. 如同时升级，先完成核心版本与数据库验收，再建立新的 QUIC 回滚点，避免为
   撤销端口变更而误回滚数据库。

```bash
openssl x509 -in /srv/netbird-relay-tls/netbird.example.com.crt \
  -noout -dates -checkhost netbird.example.com
```

TLS 证书目录应由已有证书管理流程维护；不能仅复制一次证书后忘记续期。

## 4. 备份与差异预览

```bash
QUIC_BACKUP="backup/quic-$(date +%Y%m%d-%H%M%S)"
install -d -m 700 "$QUIC_BACKUP"
cp docker-compose.yml Caddyfile "$QUIC_BACKUP/"
docker compose config --images > "$QUIC_BACKUP/images.txt"
sha256sum "$QUIC_BACKUP/docker-compose.yml" "$QUIC_BACKUP/Caddyfile"
```

备份如包含凭据，权限保持受限，异机副本加密。确认旧镜像仍可用，并保留带外
管理入口；如果 SSH 本身走即将切换的中继，应采用已授权的自动回滚或独立管理路径。

## 5. 修改现有配置

以下是**合并到现有文件的片段**。保留原 `env_file` 中的认证配置、网络、卷及
其他服务。不可把片段整体覆盖到生产 Compose。

```yaml
services:
  caddy:
    image: caddy:2.11.4
    ports:
      - "80:80"
      - "443:443"
    # 移除原来的 443:443/udp；保留原有 volumes/networks 等配置。
  relay:
    image: netbirdio/relay:0.78.1
    environment:
      NB_LISTEN_ADDRESS: ":33080"
      NB_TLS_CERT_FILE: /etc/netbird-relay/tls/netbird.example.com.crt
      NB_TLS_KEY_FILE: /etc/netbird-relay/tls/netbird.example.com.key
    ports:
      - "443:33080/udp"
    volumes:
      - /srv/netbird-relay-tls:/etc/netbird-relay/tls:ro
```

原 `NB_EXPOSED_ADDRESS` 继续使用同一 `rels://netbird.example.com:443`。原认证密钥
继续从既有安全配置加载，本次不轮换，也不创建 Setup Key。

Caddy 的全局协议去掉 `h3`，避免继续宣告已移交的 HTTP/3 UDP 入口；保留原有
其他全局设置和路由。Relay 上游改成受证书校验保护的 TLS：

```caddyfile
{
    servers :80,:443 {
        protocols h1 h2c h2
    }
}

netbird.example.com {
    reverse_proxy /relay* https://relay:33080 {
        transport http {
            tls_server_name netbird.example.com
        }
    }
    # 此处继续保留原 Management、Signal、Dashboard 和 IdP 路由。
}
```

不要使用 `https://relay:80`：Caddy 会拒绝 HTTPS scheme 与 HTTP 标准端口冲突。
不要用 `tls_insecure_skip_verify` 掩盖证书名称错误。TLS 与 QUIC 不能只增加端口
映射而不配置 Relay 自身的证书。

## 6. 校验与分阶段切换

```bash
docker compose config --quiet
cat Caddyfile | docker compose exec -T caddy \
  caddy adapt --adapter caddyfile --config /dev/stdin > /tmp/netbird-caddy-adapted.json
```

`adapt` 成功只是配置语法检查，不会应用配置，也不证明证书或 QUIC 数据面成功。
必须同时完成 [证书更新处理](relay-certificate-refresh.md)。

经授权进入维护窗口后，先由 Caddy 释放 UDP 443，再创建 Relay 的新监听：

```bash
docker compose up -d --no-deps caddy
docker compose up -d --no-deps relay
docker compose logs --since=5m --tail=100 relay
```

这里会有短暂中继/控制连接重连，不执行 `down`、`down -v` 或 `--remove-orphans`。
不要重启 Routing Peer、数据库、IdP、Docker 或 Kubernetes 网络来“帮助收敛”。

## 7. 验证与失败停止条件

必须分开验证：

| 证据 | 能证明什么 | 不能证明什么 |
| --- | --- | --- |
| Relay 的 QUIC/WS listening 日志 | 两种监听已启动 | 公网 UDP 可达 |
| 独立客户端 `Available via quic` | QUIC 连接能力及握手 | 业务流量一定走了中继 |
| WebSocket HTTP 101 | TLS/升级入口可用 | NetBird 认证、转发和完整回退数据面 |
| `Connection type: P2P` | 对该 Peer 走直连 | QUIC 中继吞吐 |
| `Relayed` + 真实业务 + 传输计数增长 | 对应中继数据路径生效 | 其他 Peer 和协议都健康 |

验证管理首页、未授权 API、OIDC discovery 的预期响应；未授权 API 不应变成
允许匿名访问。检查原 Policy/Group/Resource 和 Peer 身份是否保持。

授权客户端按照 [多服务验收](remote-development-timeouts.md#6-稳定远程开发验收)
测试 Redis、MQ、Nacos；非授权客户端应仍不能通过 NetBird 获得未授权资源。
如果没有非授权测试设备，明确记录“策略未变，非授权数据面未独立实测”。

若无法建立 QUIC、WS 回退损坏、原资源持续不可达或身份改变，停止扩大范围。
只在权限和回滚明确的专用测试设备上临时改变传输选择；不得为了制造回退，
给全体 Peer 关闭 UDP 或改掉原有防火墙。

## 8. 回滚

先停止本次新增的证书更新 timer，避免它在回滚期间尝试重载。
然后停止当前 Relay，释放其 UDP 443，恢复两份原配置并只重建这两个服务：

```bash
: "${QUIC_BACKUP:?set the verified QUIC backup directory}"
sudo systemctl disable --now netbird-relay-cert-refresh.timer
docker compose stop -t 15 relay
cp "$QUIC_BACKUP/docker-compose.yml" docker-compose.yml
cp "$QUIC_BACKUP/Caddyfile" Caddyfile
docker compose up -d --no-deps caddy
docker compose up -d --no-deps relay
```

再次验证 WS、管理入口与业务资源。QUIC 配置回滚不需要恢复 Management 数据库，
也不删除 Peer 身份卷。没有新增 timer 的环境省略对应命令。

## 9. 已完成的脱敏实测

在一次存量外部 IdP 部署中，核心组件升级到 `0.78.2`、Dashboard 到 `v2.92.0`，
数据库完整性与对象数量保持；独立 Relay 补齐 TLS 与 QUIC，客户端观察到
`via quic`，WS 升级返回 101，证书未变化时检查任务不重启 Relay。

五个在用 Routing Peer（两台独立主机、双节点 Kubernetes、一个定向出口）逐个
升级并保持身份、资源及原 Kernel/Userspace 模式。Kubernetes 业务网络和监控
通过回归，普通业务容器未被重启。此实例中新增实际 WireGuard UDP 入站规则后，
相关 Peer 转为 P2P；不能承诺其他 NAT/防火墙环境也会自动直连。

本机业务测试走实际 P2P 路径；QUIC Available 和 WS 101 的验证边界如上表。
未把两者夸大为强制中继的完整性能/故障注入测试。新装组合容器、其他内核和
客户端版本仍需各自验收。

## 10. 官方参考

- [连接与 NAT](https://docs.netbird.io/about-netbird/understanding-nat-and-connectivity)
- [外部反向代理](https://docs.netbird.io/selfhosted/external-reverse-proxy)
- [Relay 监听源码](https://github.com/netbirdio/netbird/blob/v0.78.2/relay/server/server.go)
- [TLS 文件加载源码](https://github.com/netbirdio/netbird/blob/v0.78.2/encryption/cert.go)
- [中继排障](https://docs.netbird.io/help/troubleshooting-relayed-connections)
