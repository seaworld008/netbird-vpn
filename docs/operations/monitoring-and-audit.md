# 监控、审计与持续巡检

> 本文用于把 NetBird 从“能用”推进到“可长期运营”。重点是关键节点在线、策略变更可追踪、资源访问可验证。

## 1. 监控目标

至少监控：

- NetBird 服务端是否可访问。
- Dashboard / Management 是否正常。
- 关键 Routing Peer 是否在线。
- Exit Node 出口 IP 是否正确。
- Reverse Proxy 服务是否可访问。
- 关键 Network Resource 是否仍可连通。
- Setup Key 是否过期或泄露风险。
- 临时策略是否到期未关闭。

## 2. 服务端巡检命令

在 NetBird 服务端：

```bash
docker compose ps
docker compose logs --tail=100
curl -I https://netbird.example.com
```

建议每天至少执行一次，或者接入现有监控系统。

## 3. 路由节点巡检命令

在每台 Routing Peer：

```bash
netbird status
netbird status -d
sysctl net.ipv4.ip_forward
ip route
```

关键资源连通性：

```bash
nc -vz 10.20.10.20 443
nc -vz 10.20.20.10 22
curl -k -I https://10.20.10.20
```

## 4. 客户端侧巡检

随机抽取授权用户设备：

```bash
netbird status
netbird networks ls
curl -k -I https://10.20.10.20
```

随机抽取非授权用户设备：

```bash
curl -k -I --connect-timeout 5 https://10.20.10.20
```

预期非授权失败。

## 5. Kubernetes Routing Peer 联合巡检

集群内 Routing Peer 不能只监控自己的 Ready / Connected。至少联合检查：

```bash
kubectl -n netbird-routing get daemonset,pod -o wide
kubectl -n netbird-routing logs \
  -l app.kubernetes.io/name=netbird-k8s-routing-peer --since=15m \
  | grep -Ei 'error|panic|firewall|netlink|route' || true
```

再从 Routing Peer 所在节点的普通业务 Pod 验证：

```bash
kubectl -n demo exec deploy/example -- \
  curl --noproxy '*' -fsS --connect-timeout 5 http://10.96.10.20:8080/health
kubectl -n demo exec deploy/example -- \
  curl --noproxy '*' -fsS --connect-timeout 5 http://10.60.0.12:30080/health
kubectl -n demo exec deploy/example -- \
  curl --noproxy '*' -fsS --connect-timeout 5 https://metrics.example.com/health
```

监控系统还应记录 remote-write 的成功请求、错误请求和待发送队列。判断恢复时，
不能只看待发送队列为零；还要确认成功发送计数在两个采样点之间持续增长。

建议告警：

| 告警 | 建议条件 |
| --- | --- |
| Routing Peer 副本不足 | 期望副本与 Ready 副本不一致超过 3 分钟 |
| Peer 失去 Network | `netbird status` 不再显示预期 CIDR |
| 业务 Pod 远端 NodePort 失败 | 连续 3 次 TCP / HTTP 检查失败 |
| remote-write 停止 | 成功计数 5 分钟不增长或待发送队列持续增长 |
| 网络后端异常 | NetBird 日志出现持续 firewall / netlink 错误 |

完整上线、隔离和回滚流程见 [Kubernetes 集群内 Routing Peer 生产运维手册](kubernetes-routing-peer-runbook.md)。

## 6. 简单巡检脚本

保存为 `netbird-smoke-check.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

NETBIRD_URL="${NETBIRD_URL:-https://netbird.example.com}"

echo "==> Dashboard"
curl -fsSI "$NETBIRD_URL" >/dev/null

echo "==> NetBird client"
netbird status >/dev/null

echo "==> Critical resources"
nc -vz -w 5 10.20.10.20 443
nc -vz -w 5 10.20.20.10 22

echo "ok"
```

执行：

```bash
chmod +x netbird-smoke-check.sh
NETBIRD_URL=https://netbird.example.com ./netbird-smoke-check.sh
```

## 7. Dashboard 审计重点

建议每周检查：

| 页面 | 检查点 |
| --- | --- |
| `Peers` | 关键 Routing Peer 是否在线，离线 Peer 是否堆积 |
| `Access Control > Policies` | 是否有临时策略、`All` 大权限策略 |
| `Access Control > Groups` | 用户/设备是否误入高权限组 |
| `Networks` | 资源是否误加入 `All` 或大资源组 |
| `Settings > Setup Keys` | 是否有长期可用、无限次数、无人负责的 key |
| `Control Center` | 拓扑中是否出现异常访问关系 |

## 8. 变更审计模板

每次变更记录：

```markdown
## YYYY-MM-DD NetBird 变更

- 变更人：
- 变更原因：
- 影响用户组：
- 影响资源组：
- 新增 / 修改策略：
- 验证命令：
- 非授权验证：
- 回滚步骤：
- 结果：
```

## 9. 告警建议

如果接入 Prometheus、Zabbix、Uptime Kuma 或云监控，可以配置：

| 告警 | 建议阈值 |
| --- | --- |
| Dashboard HTTPS 不可用 | 连续 3 次失败 |
| Routing Peer 离线 | 超过 3 分钟 |
| Exit Node 出口 IP 错误 | 任意一次失败 |
| Reverse Proxy 关键服务 5xx | 连续 3 次失败 |
| 关键资源端口不可达 | 连续 3 次失败 |
| Setup Key 长期未轮换 | 超过 30 或 90 天，按环境定 |

## 10. Setup Key 巡检

重点找：

- 无过期时间。
- 无使用次数限制。
- 用途不明。
- 生产和测试共用。
- 曾出现在脚本、CI 日志或文档里。

处理：

1. 新建用途明确的 key。
2. 更新自动化脚本。
3. Revoke 旧 key。
4. 检查是否有异常新 Peer。

## 11. 安全事件初步响应

如果怀疑账号或 key 泄露：

1. Revoke 可疑 Setup Key。
2. 禁用可疑用户。
3. 从高权限组移除可疑 Peer。
4. 禁用相关策略。
5. 检查 Dashboard 活动记录。
6. 轮换 IdP / API token。
7. 记录事件时间线。

如果怀疑路由节点被入侵：

```bash
sudo netbird down
sudo systemctl stop netbird
```

然后在 Dashboard 删除该 Peer，并替换 Setup Key。

## 12. 巡检和告警回滚

监控脚本、告警规则和审计流程也要能回滚，尤其是第一次上线时，避免错误告警刷屏或错误脚本误判生产故障。

### 12.1 回滚 cron 巡检

如果你把巡检脚本放进 cron，先查看：

```bash
crontab -l
```

注释或删除对应行后保存，再确认：

```bash
crontab -l
```

### 12.2 回滚 systemd timer

如果你使用 systemd timer：

```bash
systemctl list-timers | grep -i netbird
sudo systemctl disable --now netbird-smoke.timer
sudo systemctl status netbird-smoke.timer
```

只停止 timer，不会删除脚本文件。确认告警停止后，再决定是否删除脚本。

### 12.3 回滚错误告警规则

如果告警规则误报：

1. 先把告警切到静默或低优先级。
2. 保留最近 24 小时日志。
3. 修正阈值，例如连续失败 3 次再告警。
4. 用手工命令验证真实状态。
5. 再恢复告警。

手工验证命令：

```bash
docker compose ps
curl -I https://netbird.example.com
netbird status
```

### 12.4 回滚泄露的通知凭据

如果巡检脚本里使用了 Webhook、API token 或邮件密码，并怀疑泄露：

1. 立即禁用旧凭据。
2. 生成新凭据。
3. 更新运行环境变量或 secret。
4. 检查 Git、CI 日志、终端历史里是否出现旧凭据。
5. 记录凭据轮换时间和影响范围。

## 13. 官方参考

- Control Center：https://docs.netbird.io/manage/control-center
- Access Control：https://docs.netbird.io/manage/access-control/manage-network-access
- Setup Keys：https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
- Public API：https://docs.netbird.io/manage/public-api
- Security Use Cases：https://docs.netbird.io/use-cases/security
