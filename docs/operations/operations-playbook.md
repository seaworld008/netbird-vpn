# 运维手册（部署、备份、升级、回滚、排障）

> 本文是自建 NetBird 的日常运维 SOP。服务端默认是官方脚本生成的 Docker Compose 环境，场景路由节点默认是 Linux VM 或 K8S Pod。

## 1. 部署后首次检查

在 NetBird 服务端目录执行：

```bash
docker compose ps
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker compose logs --tail=200
```

从外部电脑检查：

```bash
curl -I https://netbird.example.com
```

客户端检查：

```bash
netbird status
netbird status -d
```

预期：

- Dashboard 能打开。
- 首次访问进入 `/setup` 创建管理员。
- 客户端能显示 `Connected`。
- Dashboard 里能看到 Peer 在线。

## 2. 备份

### 2.1 配置备份

在服务端目录执行：

```bash
BACKUP_DIR="backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp docker-compose.yml config.yaml dashboard.env "$BACKUP_DIR"/ 2>/dev/null || true
cp proxy.env caddyfile-netbird.txt nginx-netbird.conf npm-advanced-config.txt "$BACKUP_DIR"/ 2>/dev/null || true
docker compose config > "$BACKUP_DIR/docker-compose.rendered.yml"
find "$BACKUP_DIR" -maxdepth 1 -type f -print | sort
```

### 2.2 数据卷备份

先找真实卷名：

```bash
docker volume ls | grep -i netbird
docker volume ls | grep -i traefik
```

备份主数据卷：

```bash
BACKUP_DIR="backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
docker run --rm \
  -v <actual_netbird_data_volume>:/data:ro \
  -v "$PWD/$BACKUP_DIR":/backup \
  busybox tar czf /backup/netbird_data.tgz -C /data .
```

如果你使用内置 Traefik，也备份证书卷：

```bash
docker run --rm \
  -v <actual_traefik_letsencrypt_volume>:/data:ro \
  -v "$PWD/$BACKUP_DIR":/backup \
  busybox tar czf /backup/traefik_letsencrypt.tgz -C /data .
```

不要把备份只放在同一台机器上，至少同步到对象存储、NAS 或离线备份位置。

## 3. 升级

升级前：

1. 看 [上游版本状态](../selfhosted/upstream-version-status.md)。
2. 做配置和数据卷备份。
3. 确认有回滚窗口。
4. 如果是生产环境，先在测试环境验证客户端登录、路由、DNS、Exit Node、Reverse Proxy。

独立 Management、Signal、Relay 和外部 IdP 的老部署先按 [Legacy 外部 IdP 部署升级与回滚](legacy-external-idp-upgrade.md) 判断迁移边界，不直接套用新架构迁移工具。

执行：

```bash
docker compose config --images
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --tail=200
```

升级后验证：

```bash
curl -I https://netbird.example.com
netbird status
```

如果涉及路由节点，再验证至少一个资源：

```bash
nc -vz <target-ip> <port>
curl -k -I https://<target>
```

## 4. 回滚

### 4.1 配置回滚

```bash
cp backup/<backup-dir>/docker-compose.yml .
cp backup/<backup-dir>/config.yaml .
cp backup/<backup-dir>/dashboard.env .
cp backup/<backup-dir>/proxy.env . 2>/dev/null || true
docker compose up -d
docker compose ps
```

### 4.2 数据卷回滚

数据回滚会覆盖当前数据，必须在维护窗口内执行。

```bash
docker compose down
docker run --rm \
  -v <actual_netbird_data_volume>:/data \
  -v "$PWD/backup/<backup-dir>":/backup \
  busybox sh -c 'rm -rf /data/* && tar xzf /backup/netbird_data.tgz -C /data'
docker compose up -d
```

### 4.3 场景配置回滚

对于 `Networks`、资源、策略：

1. 先禁用策略。
2. 再禁用或删除资源。
3. 再移除用户组。
4. 最后下线路由节点。

路由节点下线：

```bash
sudo netbird down
sudo systemctl stop netbird
```

## 5. 网络资源不通排障顺序

按这个顺序查，避免来回跳：

### 5.1 客户端侧

```bash
netbird status
netbird status -d
netbird networks ls
nc -vz <target-ip> <port>
curl -k -I https://<target>
```

检查：

- 客户端是否在线。
- 客户端是否在正确用户组。
- 是否拿到了目标 Network。
- 端口是否是策略允许的端口。

### 5.2 路由节点侧

```bash
netbird status
netbird status -d
sysctl net.ipv4.ip_forward
ip route
nc -vz <target-ip> <port>
curl -k -I https://<target>
```

检查：

- 路由节点是否在线。
- 路由节点是否在正确 routing peer group。
- 路由节点本机是否能访问目标。
- `ip_forward` 是否开启。

### 5.3 服务端 / Dashboard 侧

检查：

- `Networks` 资源是否写对。
- 资源是否在正确资源组。
- 策略源组 / 目标组是否写反。
- 端口是否漏写。
- 默认 `All -> All` 是否造成误放行。

### 5.4 目标服务侧

检查：

```bash
sudo ss -lntp
sudo iptables-save 2>/dev/null | head
sudo nft list ruleset 2>/dev/null | head
```

常见问题：

- 服务只监听 `127.0.0.1`。
- 防火墙未允许路由节点来源。
- 后端白名单仍是旧 VPN 网段。
- HTTPS 证书只签给域名，用户却用 IP 访问。

## 6. Exit Node 排障

客户端：

```bash
netbird status -d
curl https://ifconfig.me
nslookup example.com
```

出口节点：

```bash
curl https://ifconfig.me
sysctl net.ipv4.ip_forward
```

重点检查：

- 是否有 `用户组 -> exit-node 组 -> ICMP` 策略。
- Auto Apply 是否开启，或客户端是否手动选择。
- DNS 是否配置 `ALL` match domain。
- 出口节点公网访问是否正常。

## 7. Reverse Proxy 排障

外部：

```bash
dig +short grafana.proxy.example.com
curl -vk https://grafana.proxy.example.com
```

目标 Peer：

```bash
netbird status
curl -I http://127.0.0.1:3000
curl -I http://<peer-lan-ip>:3000
```

常见问题：

- 发布域名 DNS 未解析到代理入口。
- 目标 Peer 离线。
- Target 端口写错。
- 后端外部 URL 没配置，登录后跳回内网。
- 后端没有配置 trusted proxies。

## 8. 变更记录模板

每次重要变更建议记录：

```markdown
## YYYY-MM-DD NetBird 变更

- 变更人：
- 变更目的：
- 涉及 Network：
- 涉及资源：
- 涉及策略：
- 验证命令：
- 回滚命令：
- 结果：
```

## 9. 最小日常巡检

每天或每周执行：

```bash
docker compose ps
docker compose logs --tail=100
curl -I https://netbird.example.com
```

Dashboard 检查：

- 是否有离线关键路由 Peer。
- 是否有过期或长期未 revoke 的 Setup Key。
- 是否有临时策略未关闭。
- 是否有资源误加入 `All`。
