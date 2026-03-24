# 运维手册（部署、备份、升级、回滚）

## 1. 部署后首次检查

```bash
# 检查服务状态
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

docker logs -f --tail 200 <service>
```

## 2. 备份

### 配置备份

```bash
mkdir -p backup/$(date +%Y%m%d)
cp docker-compose.yml config.yaml dashboard.env backup/$(date +%Y%m%d)/
cp proxy.env caddyfile-netbird.txt nginx-netbird.conf npm-advanced-config.txt backup/$(date +%Y%m%d)/ 2>/dev/null || true
```

### 数据备份

```bash
# 示例：备份 NetBird 主数据卷（SQLite、密钥、状态）
docker run --rm -v netbird_data:/backup busybox tar czf - /backup > backup/$(date +%Y%m%d)/netbird_data.tgz
```

## 3. 升级

1. 先备份
2. 停机窗口内更新镜像
3. 观察日志与健康检查
4. 回滚前保留旧版本镜像

```bash
docker compose pull
docker compose up -d

docker compose ps
```

## 4. 回滚策略

- 快速回滚：复用上一次 compose 文件与镜像标记
- 数据回滚：优先恢复卷快照，再恢复配置文件（按业务窗口）

## 5. 问题排查顺序

1. DNS 与端口
2. 身份服务与 token 失效
3. `netbird-server` 与 STUN 3478/udp 是否可达
4. 网络策略是否误放行
5. 客户端日志与版本差异

## 6. 对外发布建议

- 每次变更写入简易 CHANGELOG
- 关键变更保留回滚指令
- 以文档版本（YYYYMMDD）同步到 `docs/*` 内的案例与 SOP
