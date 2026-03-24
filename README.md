# NetBird 自建部署与实践手册（对齐官方最新文档）

> 该仓库用于把 NetBird 的部署与实践知识整理成可直接交付给团队/社区的手册。
> 目标：既能兼容已有历史环境，也能无歧义地引导到最新稳定实践。

## 一、仓库定位

- **推荐路径（最新）**：基于 `getting-started.sh`，适配 NetBird 近期版本（含本地用户能力）。
- **部署标准**：服务端统一采用 `docker-compose`；本仓库不再保留 legacy 配置模板，不维护本地安装脚本。
- **变更原则**：执行官方脚本生成基线文件，然后只改配置文件。

## 二、先说结论：当前 README 旧步骤是否已过期？

是，部分已过时。

- 官方脚本入口已经从早期的 `getting-started-with-zitadel.sh` 移向 `getting-started.sh`，且默认推荐更符合新版本部署方式。
- 新版强调在安装阶段直接选择反向代理模式（Traefik 默认，支持接入现有 Nginx/Caddy 等）。
- 官方文档中的新版安装模板正逐步收敛到合并服务形态（`netbird-server`），与你当前仓库的拆分容器模型存在兼容差异。

> 你现在这个仓库更适合作为“历史基线 + 迁移文档仓库”，我已把它重构成可直接指导“最新主线 + legacy 兼容”的文档结构。

## 三、5 分钟启动（推荐）

```bash
# 准备域名变量（必须先把域名解析到服务器）
export NETBIRD_DOMAIN=netbird.example.com

# 推荐：直接执行官方脚本
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh | bash
```

安装后访问：

```text
https://netbird.example.com
```

客户端下载：

```text
https://docs.netbird.io/get-started/install
```

## 四、仓库结构（建议阅读顺序）

```text
.
├── README.md                         # 主文档（快速定位）
├── 部署说明.md                       # 快速部署与入口说明
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── docs/
│   ├── selfhosted/
│   │   ├── quickstart-modern.md       # 官方推荐安装与参数核对
│   │   ├── docker-compose-config-cheatsheet.md # 配置文件速查（非脚本）
│   ├── cases/
│   │   ├── 01-openvpn-replacement.md
│   │   ├── 02-whitelisted-system-access.md
│   │   ├── 03-kubernetes-connectivity.md
│   │   ├── 04-exit-node-and-proxy.md
│   │   ├── 05-multi-cloud-connectivity.md
│   │   └── 06-official-advanced-scenarios.md
│   └── operations/
│       ├── firewall-and-hardening.md
│       └── operations-playbook.md
```

## 五、你要的“跳转入口”（先读哪个）

### 部署链路

- [官方推荐一体化部署说明（新手推荐）](docs/selfhosted/quickstart-modern.md)
- [服务器端配置速查（无脚本化）](docs/selfhosted/docker-compose-config-cheatsheet.md)

### 场景实践（可直接放给他人）

- [案例 1：用 NetBird 替代 OpenVPN（零信任接入）](docs/cases/01-openvpn-replacement.md)
- [案例 2：企业内网白名单系统接入](docs/cases/02-whitelisted-system-access.md)
- [案例 3：本地办公访问 K8S 集群/Pod 网络](docs/cases/03-kubernetes-connectivity.md)
- [案例 4：NetBird 统一出口与反向代理实践](docs/cases/04-exit-node-and-proxy.md)
- [案例 5：多云内网互通（AWS/GCP/Azure）](docs/cases/05-multi-cloud-connectivity.md)
- [案例 6：官方推荐的安全与高级实践清单](docs/cases/06-official-advanced-scenarios.md)

### 运维

- [阿里云安全组与端口说明](docs/operations/firewall-and-hardening.md)
- [日常运维与故障排查（备份/回滚/升级）](docs/operations/operations-playbook.md)

## 六、基础端口与网络基线

| 协议 | 端口 | 场景 |
| --- | --- | --- |
| TCP | 80 | HTTP/ACME 校验 |
| TCP | 443 | HTTPS 与管理面 |
| UDP | 3478 | STUN |
| UDP | 443 | HTTP/3（按反向代理配置决定，非必需） |

> 新版主线默认最少只需开放 TCP 80、TCP 443、UDP 3478；管理端口务必来源白名单。

## 七、阿里云安全组怎么配

如果你的服务器在阿里云，最少按下面几条入方向规则放行：

| 方向 | 协议 | 端口范围 | 授权对象 | 作用 |
| --- | --- | --- | --- | --- |
| 入方向 | TCP | 80/80 | `0.0.0.0/0` | 证书签发、HTTP 跳转 |
| 入方向 | TCP | 443/443 | `0.0.0.0/0` | Dashboard 和管理入口 |
| 入方向 | UDP | 3478/3478 | `0.0.0.0/0` | STUN，帮助客户端做 NAT 探测 |
| 入方向 | UDP | 443/443 | `0.0.0.0/0` | 可选，仅当你启用了 HTTP/3 |

阿里云控制台填写建议：

1. 安全组类型选择“入方向”。
2. 授权策略选择“允许”。
3. 优先级可统一填 `1` 或更小的高优先级值。
4. 授权对象公网开放时填 `0.0.0.0/0`；如果是办公网白名单，就改成你的固定出口 IP 或 CIDR。
5. 备注里直接写端口用途，例如 `NetBird HTTPS`、`NetBird STUN`，后续排障更容易。

新手最容易犯的错误：

- 只开放了 `443/tcp`，忘了 `3478/udp`，结果客户端经常连不上或 NAT 打洞异常。
- 域名已经解析，但 `80/tcp` 没开放，导致证书申请失败。
- 把安全组配好了，但服务器本机 `ufw` / `firewalld` 还在拦截。

## 八、官方资源索引

- 官方文档首页：https://docs.netbird.io/
- 官方客户端安装入口：https://docs.netbird.io/get-started/install
- 自建快速开始（推荐）：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- 自建反向代理说明（官方）：https://docs.netbird.io/selfhosted/reverse-proxy
- 配置文件参考（新部署）：https://docs.netbird.io/selfhosted/configuration-files
- 本地身份管理说明（内置 IdP）：https://docs.netbird.io/selfhosted/identity-providers/local
- 访问控制文档（官方）：https://docs.netbird.io/manage/access-control/manage-network-access
- 路由网络访问限制（官方）：https://docs.netbird.io/manage/networks/accessing-restricted-domain-resources

## 九、快速对外发布建议

1. 新用户默认只看 `docs/selfhosted/quickstart-modern.md`。
2. 每个场景文档都给出：
   - 前置条件
   - 拓扑图（文字图）
   - 命令 / 控制台点击路径
   - 校验清单
   - 典型问题与排障
3. 文档更新时间建议使用 `YYYY-MM-DD` 标记版本，方便多人协作。

> 我们对外建议：不要求用户修改部署脚本，默认只给“官方脚本入口 + 配置文件模板 + 场景文档”。
> 服务端仍坚持 `docker-compose` 部署；K8S 场景仅用于网络打通节点例外场景。

## 十、仓库规范化补充

- 开源协作说明：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 安全响应流程：[SECURITY.md](./SECURITY.md)
- 版本与变更记录：[CHANGELOG.md](./CHANGELOG.md)
- 文档目录索引：[docs/README.md](./docs/README.md)

建议将本仓库以 `docs/` 为主入口，根目录文件只保留入口和治理文档，其余实践统一沉淀到 `docs/`。

## 十一、官方能力核对（以避免版本偏差）

- 反向代理功能：自托管环境建议优先使用 Traefik 场景，且需确保 `getting-started.sh` 与反向代理能力匹配。
- 新版自建默认会生成 `docker-compose.yml`、`config.yaml`、`dashboard.env`，并按反向代理选项生成额外模板文件。
- Reverse Proxy、Expose、Browser Client 等能力请始终以官方文档和 release note 为准。
