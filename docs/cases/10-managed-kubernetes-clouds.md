# 案例十：托管 K8S 云厂商专项（ACK / EKS / GKE / AKS）

> 本文是在案例三 K8S 网络打通基础上的云厂商补充。重点不是重复 YAML，而是告诉你在托管 K8S 里应该检查哪些云侧开关。

## 1. 最终效果

你可以判断：

- 路由节点应该放在哪个 VPC / VNet / 子网。
- API Server 内网地址是否可访问。
- Pod CIDR / Service CIDR 如何确认。
- 云安全组 / Firewall / NSG 应该放通什么。
- 什么时候用 VM 路由节点，什么时候用 K8S 内 Deployment 或 Operator。

## 2. 推荐架构

新手优先：

```text
同 VPC / VNet Linux VM Routing Peer -> K8S API Server / Pod CIDR / Service CIDR
```

熟悉 K8S 后再考虑：

```text
NetBird Kubernetes Operator -> NetworkRouter / NetworkResource
```

原因：

- VM 路由节点最容易排障。
- 托管 K8S 的 CNI、Service CIDR、API Server endpoint 在不同云差异很大。
- Operator 更自动，但依赖 CRD、API token、DNS zone、权限和 webhook。

## 3. 通用检查清单

先填写：

| 项目 | 示例 |
| --- | --- |
| 集群名称 | `prod-k8s` |
| 云厂商 | `ACK / EKS / GKE / AKS` |
| VPC / VNet CIDR | `10.60.0.0/16` |
| Node 子网 | `10.60.0.0/24` |
| Pod CIDR | `10.244.0.0/16` |
| Service CIDR | `10.96.0.0/16` |
| API Server 内网地址 | `10.60.0.5:6443` |
| 路由节点 | `10.60.0.10` |

通用命令：

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get svc kubernetes -o wide
kubectl get pods -A -o wide | head -30
```

路由节点测试：

```bash
nc -vz 10.60.0.5 6443
curl -k https://10.60.0.5:6443/version
```

## 4. ACK 检查点

阿里云 ACK 常见关注点：

- 集群 API Server 是否启用内网访问。
- ECS 路由节点是否在同一 VPC 或已打通的 VPC。
- 安全组是否允许路由节点访问 API Server、Node、Pod。
- Terway / Flannel 等 CNI 模式下 Pod IP 是否 VPC 可路由。
- Service CIDR 是否只能在集群内访问。

建议：

| 项目 | 建议 |
| --- | --- |
| 路由节点 | 同 VPC ECS |
| API Server | 优先内网 endpoint |
| Pod 访问 | 先测 Pod IP，再测 Service IP |
| 安全组 | 目标侧允许路由节点 IP |

路由节点验证：

```bash
: "${ACK_API_IP:?set the ACK private API server IP}"
: "${ACK_API_URL:?set the ACK API URL from kubeconfig, including scheme}"

nc -vz "$ACK_API_IP" 6443
curl --fail --show-error "${ACK_API_URL%/}/version"
```

## 5. EKS 检查点

AWS EKS 常见关注点：

- Cluster endpoint 是否允许 private access。
- Routing Peer 是否在同一个 VPC 或通过 VPC peering / TGW 可达。
- Security Group for Pods / Node security group 是否允许路由节点来源。
- Pod CIDR 是 VPC CNI 分配还是自定义网络。

建议安全组思路：

| 目标 | 入方向来源 | 端口 |
| --- | --- | --- |
| API Server endpoint | 路由节点安全组 | `443` / `6443`，以集群实际为准 |
| Node | 路由节点安全组 | 业务端口 |
| Pod | 路由节点安全组或 Node 安全组 | 业务端口 |

验证：

```bash
EKS_ENDPOINT="$(
  aws eks describe-cluster --name prod-k8s \
    --query 'cluster.endpoint' --output text
)"
EKS_HOST="${EKS_ENDPOINT#https://}"
test -n "$EKS_HOST"

aws eks describe-cluster --name prod-k8s \
  --query 'cluster.resourcesVpcConfig'
nc -vz "$EKS_HOST" 443
```

如果 API Server endpoint 是域名，优先用 kubeconfig 中的域名，并在 NetBird 添加 Domain Resource。

## 6. GKE 检查点

GKE 常见关注点：

- Private cluster / private endpoint 配置。
- Master authorized networks 是否限制来源。
- VPC-native 集群下 Pod CIDR / Service CIDR。
- Firewall rules 是否允许路由节点来源。

建议：

| 项目 | 建议 |
| --- | --- |
| 路由节点 | 同 VPC Compute Engine VM |
| API Server | 私有 endpoint 或授权公网 endpoint |
| 防火墙 | 允许路由节点到控制面和目标 Pod / Service |

验证：

```bash
: "${GKE_REGION:?set the GKE region}"
GKE_PRIVATE_ENDPOINT="$(
  gcloud container clusters describe prod-k8s \
    --region "$GKE_REGION" \
    --format='value(privateClusterConfig.privateEndpoint)'
)"
test -n "$GKE_PRIVATE_ENDPOINT"
nc -vz "$GKE_PRIVATE_ENDPOINT" 443
```

如果使用 Master authorized networks，确认路由节点出口 IP 在授权范围内。

## 7. AKS 检查点

AKS 常见关注点：

- Private cluster 是否启用。
- API Server VNet integration / private endpoint。
- Azure CNI 或 kubenet 的 Pod 路由差异。
- NSG 是否允许路由节点来源。

建议：

| 项目 | 建议 |
| --- | --- |
| 路由节点 | 同 VNet VM |
| API Server | private endpoint |
| NSG | 允许路由节点到 API Server、Node、Pod |

验证：

```bash
AKS_PRIVATE_FQDN="$(
  az aks show --resource-group rg-prod --name prod-k8s \
    --query privateFqdn -o tsv
)"
test -n "$AKS_PRIVATE_FQDN"
nc -vz "$AKS_PRIVATE_FQDN" 443
```

如果 private FQDN 解析失败，需要让路由节点使用能解析该私有域名的 DNS。

## 8. NetBird 配置建议

无论哪个云，NetBird 侧保持同样模型：

| 资源名 | 类型 | 值 | 资源组 |
| --- | --- | --- | --- |
| `k8s-prod-apiserver` | IP / Domain | `10.60.0.5/32` 或 `api.prod.internal` | `k8s-api` |
| `k8s-prod-nodes` | IP Range | `10.60.0.0/24` | `k8s-nodes` |
| `k8s-prod-pods` | IP Range | `10.244.0.0/16` | `k8s-pods` |
| `k8s-prod-services` | IP Range | `10.96.0.0/16` | `k8s-services` |

策略从小到大：

1. 只放 `k8s-api -> TCP 6443/443`。
2. 再放具体 Pod / Service。
3. 最后再考虑大网段。

## 9. 验证顺序

1. 路由节点能访问 API Server。
2. 本地开发机能通过 NetBird 访问 API Server。
3. `kubectl get ns` 成功。
4. 路由节点能访问 Demo Pod IP。
5. 本地开发机能访问 Demo Pod IP。
6. 路由节点能访问 Demo Service IP。
7. 本地开发机能访问 Demo Service IP。

命令：

```bash
: "${POD_IP:?set the demo Pod IP}"
: "${SERVICE_IP:?set the demo Service IP}"

kubectl --kubeconfig ./prod-k8s-netbird.kubeconfig get ns
curl --fail --show-error --head "http://${POD_IP}"
curl --fail --show-error --head "http://${SERVICE_IP}"
```

## 10. 排障

### 10.1 API Server 不通

检查：

- private endpoint 是否启用。
- 路由节点 DNS 是否能解析 API 域名。
- 云控制面访问白名单是否包含路由节点。
- NetBird 策略是否放通端口。

### 10.2 Pod IP 不通

检查：

- CNI 模式下 Pod IP 是否可从 VPC 访问。
- 云防火墙 / 安全组是否允许路由节点来源。
- Pod NetworkPolicy 是否拦截。

### 10.3 Service IP 不通

先确认 Pod IP 通。Service CIDR 很多时候只在集群内语义更清晰，跨 VPC 访问可能受 kube-proxy / CNI 影响。必要时优先暴露具体 Pod 或内部 Ingress。

## 11. 回滚

托管 K8S 场景回滚时，按“先撤权限，再撤资源，再撤路由节点”的顺序做，避免正在使用的客户端突然拿到不完整路由。

### 11.1 Dashboard 侧回滚

1. 禁用或删除 `dev-users -> k8s-api` 的访问策略。
2. 禁用 Pod CIDR / Service CIDR 相关策略。
3. 从用户组中移除临时测试用户。
4. 删除或禁用测试用 Network Resource。
5. 确认 `All` 组没有被误授权到 K8S 资源。

### 11.2 VM 路由节点回滚

如果你用云主机作为 Routing Peer：

```bash
sudo netbird down
sudo systemctl stop netbird
```

然后在 Dashboard 删除这个 Peer，最后收紧云安全组：

- 删除允许访问 API Server 的临时白名单。
- 删除允许访问 Pod CIDR / Service CIDR 的测试规则。
- 如果创建了专用测试 ECS / EC2 / VM，确认没有其他业务依赖后再释放。

### 11.3 Operator / Pod 路由节点回滚

如果你使用 NetBird Kubernetes Operator，先查看部署：

```bash
kubectl get pods -n netbird
helm list -n netbird
```

删除测试 Routing Peer CR：

```bash
: "${ROUTING_PEER_NAME:?set the test RoutingPeer name}"
: "${ROUTING_PEER_NAMESPACE:?set the test RoutingPeer namespace}"

kubectl get routingpeers -A
kubectl delete routingpeer "$ROUTING_PEER_NAME" -n "$ROUTING_PEER_NAMESPACE"
```

如果整个 Operator 只是为本次测试安装，可以卸载：

```bash
helm uninstall netbird-operator -n netbird
kubectl delete namespace netbird
```

删除 namespace 前确认里面没有团队正在使用的其他 NetBird 资源。

### 11.4 客户端验证回滚完成

在本地开发机执行：

```bash
: "${POD_IP:?set the demo Pod IP}"

netbird networks ls
kubectl --kubeconfig ./prod-k8s-netbird.kubeconfig get ns
curl --fail --show-error --head "http://${POD_IP}"
```

预期：

- 被撤权用户不再看到 K8S Network。
- `kubectl get ns` 对未授权用户失败。
- Pod IP / Service IP 对未授权用户不可达。

## 12. 官方参考

- K8S Routing Peers：https://docs.netbird.io/use-cases/kubernetes/routing-peers-and-kubernetes
- Kubernetes Operator：https://docs.netbird.io/use-cases/kubernetes
- Routing Peer CRD：https://docs.netbird.io/use-cases/kubernetes/routing-peer
- Routing Peers 原理：https://docs.netbird.io/manage/networks/how-routing-peers-work
