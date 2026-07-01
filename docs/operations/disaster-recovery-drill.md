# 自建 NetBird 灾备与恢复演练

> 适用范围：官方 `getting-started.sh` 生成的 Docker Compose 自建环境。本文重点是演练方法，不要求你真的在生产环境破坏数据。

## 1. 为什么要演练

NetBird 一旦用于远程办公、K8S 私有集群、多云内网、白名单系统访问，它就会变成基础设施入口。只做备份但从不恢复，等于没有验证备份可用。

灾备演练要回答 4 个问题：

- 管理端打不开时，能不能恢复 Dashboard。
- 数据卷丢失时，能不能恢复用户、Peer、策略、Networks。
- 域名或主机迁移时，客户端能不能重新连上。
- 恢复后，关键业务资源是否仍按最小权限访问。

## 2. 建议目标

| 项目 | 小团队建议 | 生产建议 |
| --- | --- | --- |
| RPO | 24 小时内 | 4 小时内或更短 |
| RTO | 2 小时内 | 30 到 60 分钟内 |
| 演练频率 | 每季度一次 | 每月或每次大版本升级前 |
| 恢复环境 | 临时测试机 | 独立灾备机或预生产环境 |

RPO 是最多能接受丢失多久的数据；RTO 是最多能接受中断多久。

## 3. 演练前准备

准备一台临时测试机，满足：

- 能运行 Docker 和 Docker Compose。
- 能访问备份存储位置。
- 有一个测试域名，例如 `netbird-dr.example.com`。
- 云安全组已放通测试用 `80/tcp`、`443/tcp`、`3478/udp`。

不要直接在生产机器上做破坏性恢复演练。生产只做备份导出和只读检查，恢复动作放到测试机。

## 4. 生产环境导出备份

在生产 NetBird 服务端目录执行：

```bash
BACKUP_DIR="backup/drill-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

cp docker-compose.yml config.yaml dashboard.env "$BACKUP_DIR"/ 2>/dev/null || true
cp proxy.env caddyfile-netbird.txt nginx-netbird.conf npm-advanced-config.txt "$BACKUP_DIR"/ 2>/dev/null || true
docker compose config > "$BACKUP_DIR/docker-compose.rendered.yml"
```

查看需要备份的数据卷：

```bash
docker volume ls | grep -Ei 'netbird|traefik|caddy'
```

把实际卷名写入变量：

```bash
NETBIRD_DATA_VOLUME="<actual_netbird_data_volume>"
TRAEFIK_CERT_VOLUME="<actual_traefik_letsencrypt_volume>"
```

备份 NetBird 数据卷：

```bash
docker run --rm \
  -v "${NETBIRD_DATA_VOLUME}":/data:ro \
  -v "$PWD/$BACKUP_DIR":/backup \
  busybox tar czf /backup/netbird_data.tgz -C /data .
```

如果你使用内置 Traefik，也备份证书卷：

```bash
docker run --rm \
  -v "${TRAEFIK_CERT_VOLUME}":/data:ro \
  -v "$PWD/$BACKUP_DIR":/backup \
  busybox tar czf /backup/traefik_letsencrypt.tgz -C /data .
```

生成校验文件：

```bash
cd "$BACKUP_DIR"
sha256sum * > SHA256SUMS
cat SHA256SUMS
```

把整个 `$BACKUP_DIR` 同步到对象存储、NAS 或临时测试机。

## 5. 重要备份点

至少要确认备份中包含：

- `docker-compose.yml`
- `config.yaml`
- `dashboard.env`
- `proxy.env`，如果启用了 NetBird Proxy
- 外部反向代理配置，如果你不用内置 Traefik
- NetBird 主数据卷压缩包
- Traefik / Caddy 证书数据，按你的实际部署选择
- `server.store.encryptionKey` 相关配置

`server.store.encryptionKey` 对本地用户数据很关键。这个密钥丢失后，加密的用户信息可能无法恢复。

## 6. 在测试机恢复

在测试机准备目录：

```bash
mkdir -p ~/netbird-dr
cd ~/netbird-dr
```

把备份文件放到当前目录后校验：

```bash
sha256sum -c SHA256SUMS
```

创建测试数据卷：

```bash
docker volume create netbird_dr_data
docker run --rm \
  -v netbird_dr_data:/data \
  -v "$PWD":/backup \
  busybox sh -c 'tar xzf /backup/netbird_data.tgz -C /data'
```

如果需要恢复证书卷：

```bash
docker volume create netbird_dr_letsencrypt
docker run --rm \
  -v netbird_dr_letsencrypt:/data \
  -v "$PWD":/backup \
  busybox sh -c 'tar xzf /backup/traefik_letsencrypt.tgz -C /data'
```

复制配置文件：

```bash
cp docker-compose.yml config.yaml dashboard.env ~/netbird-dr/
cp proxy.env caddyfile-netbird.txt nginx-netbird.conf npm-advanced-config.txt ~/netbird-dr/ 2>/dev/null || true
```

把测试环境域名替换为灾备域名：

```bash
grep -R "netbird.example.com" -n docker-compose.yml config.yaml dashboard.env proxy.env 2>/dev/null || true
```

把生产域名替换为：

```text
netbird-dr.example.com
```

同时检查 Docker Compose 里的 volume 名称，把生产卷名改成测试卷名：

```text
netbird_dr_data
netbird_dr_letsencrypt
```

启动前渲染配置：

```bash
docker compose config >/tmp/netbird-dr-compose.yml
docker compose up -d
docker compose ps
docker compose logs --tail=200
```

## 7. DNS 和证书验证

把测试域名解析到测试机公网 IP 后验证：

```bash
dig +short netbird-dr.example.com
curl -I https://netbird-dr.example.com
```

预期：

- DNS 返回测试机公网 IP。
- HTTPS 返回 `200`、`302` 或登录页相关响应。
- `docker compose ps` 中关键容器是 `Up`。

如果证书失败：

- 检查 `80/tcp` 是否放通。
- 检查域名是否已经解析到测试机。
- 检查你是否把生产证书卷直接拿到测试域名使用。
- 如果测试域名不同，通常需要让反向代理重新申请测试域名证书。

## 8. 恢复后功能验证

先验证 Dashboard：

```bash
curl -I https://netbird-dr.example.com
```

再从一台测试客户端连接灾备域名：

```bash
sudo netbird down
sudo netbird up --management-url https://netbird-dr.example.com
netbird status
netbird status -d
```

如果你不希望影响现有生产客户端，使用单独测试机或测试容器，不要在生产办公电脑上切换管理端。

验证关键资源：

```bash
netbird networks ls
nc -vz 10.20.0.10 443
curl -k -I https://10.20.0.10
```

至少验证：

- 一个普通用户可以访问自己被授权的资源。
- 一个未授权用户访问失败。
- 一个关键 Routing Peer 在线。
- 一个 Setup Key 状态符合预期。
- 一个临时策略没有被意外打开。

## 9. 演练记录模板

```markdown
## YYYY-MM-DD NetBird 灾备演练

- 演练人：
- 生产版本：
- 备份时间：
- 备份来源：
- 恢复目标：
- RPO：
- RTO：
- 成功恢复的内容：
- 失败或异常：
- 修复动作：
- 下次改进：
```

建议把演练记录放到团队内部知识库，不要把真实域名、真实 IP、真实用户信息提交到本仓库。

## 10. 演练后的清理

如果测试机只用于临时演练：

```bash
docker compose down
docker volume ls | grep netbird_dr
```

确认不再需要后，再删除测试卷：

```bash
docker volume rm netbird_dr_data netbird_dr_letsencrypt
```

删除前再次确认它们是测试卷，不是生产卷。

## 11. 常见问题

### 登录失败

检查：

- `config.yaml` 中认证地址是否仍指向生产域名。
- `dashboard.env` 中 Dashboard / API / OIDC 地址是否替换完整。
- `server.store.encryptionKey` 是否和备份时一致。

### Peer 不自动连到灾备

客户端通常记住原管理端地址。灾备演练中不要期待生产客户端自动切换，除非你把原生产域名 DNS 切到灾备机。

真正生产故障切换时，常用做法是：

1. 在灾备机恢复数据。
2. 把原生产域名解析切到灾备机。
3. 等 DNS 生效。
4. 验证客户端重新连接。

### 资源恢复了但访问不通

按顺序检查：

- Routing Peer 是否在线。
- 目标内网是否允许灾备环境的回程。
- 云安全组和本机防火墙是否允许。
- 策略是否仍然绑定正确 Groups 和 Resources。
- Masquerade 是否开启；如果关闭，需要目标网络有回程路由。

## 12. 官方参考

- NetBird 自建快速开始：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- NetBird 配置文件参考：https://docs.netbird.io/selfhosted/configuration-files
- 本地用户与加密密钥说明：https://docs.netbird.io/selfhosted/identity-providers/local
- NetBird 控制台与管理入口：https://docs.netbird.io/manage/control-center
