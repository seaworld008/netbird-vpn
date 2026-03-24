# 案例四：把 NetBird 当作统一出口（Exit Node）和代理入口

## 场景

希望把多台分散终端统一走某台出口网关访问互联网和对外服务。

## A. Exit Node 统一出口

### 1. 选择出口节点

- 在可控网络边界部署一个高可用节点（可访问外网）
- 在节点端安装 NetBird 并允许其成为 Exit Node

### 2. 在控制台配置

1. 编辑该节点，勾选“作为 Exit Node”
2. 选择允许接入的组（如 `office-team`）

### 3. 客户端启用默认路由

- 在客户端会话设置中开启“使用该出口”
- 建议优先保留本地网关为直连网络，只有特定流量走 Exit Node，减少全量外网绕路

### 4. 核验

```bash
# 在客户端查看出口 IP
curl https://ifconfig.me
```

## B. 内部服务统一对外访问（Reverse Proxy 形态）

如果你是想把一部分内网服务统一暴露给授权网段用户：
- 方式一：先启用管理端 NetBird Reverse Proxy（自建场景）并确认 peer 已开启 `peer expose` 权限
- 方式二：自建服务网关再做 path 转发（适合已有合规网关体系的团队）

官方文档说明：
- 反向代理整体能力（beta）：https://docs.netbird.io/manage/reverse-proxy
- CLI 临时暴露（netbird expose）：https://docs.netbird.io/manage/reverse-proxy/expose-from-cli
- 自建反向代理接入说明：https://docs.netbird.io/selfhosted/reverse-proxy

### 关键原则

- 不要把控制平面和业务代理复用为同一对外入口
- 出口网关优先做最小路径规则（ACL）与来源 IP 限制
- 记录审计：谁在何时访问了哪个服务

## 风险提醒

- Exit Node 误用会带来集中风险，务必设置最小权限组
- 为出口节点加上健康检查与重连告警
