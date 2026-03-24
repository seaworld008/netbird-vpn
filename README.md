# NetBird 自建部署与实践手册（对齐官方最新文档）

> 该仓库用于把 NetBird 的部署与实践知识整理成可直接交付给团队/社区的手册。
> 目标：既能兼容已有历史环境，也能无歧义地引导到最新稳定实践。

## 一、仓库定位

- **推荐路径（最新）**：基于 `getting-started.sh`，适配 NetBird 近期版本（含本地用户能力）。
- **兼容路径（历史）**：基于 `getting-started-with-zitadel.sh`，用于已有 Zitadel 体系的续航。
- **现状说明**：本仓库根目录文件 `docker-compose.yml` / `Caddyfile` / `.template` 仍是历史产物，适合做运维对照；本地标准流程是执行官方脚本生成基线，再只改配置文件，不维护自定义安装脚本。

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

## 四、仍要用 Zitadel 的场景

如果你有既有 Zitadel 统一身份体系，按以下方式执行历史兼容流程：

```bash
export NETBIRD_DOMAIN=netbird.example.com
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh | bash
```

```text
注意：默认不依赖本地 install script，直接执行官方脚本并按流程编辑配置。
```

## 五、仓库结构（建议阅读顺序）

```text
.
├── README.md                         # 主文档（快速定位）
├── 部署说明.md                       # 原始快速说明（已改为兼容入口）
├── deploy.sh（不推荐）               # 兼容/迁移场景备用脚本
├── docker-compose.yml                 # 兼容版模板（历史基线）
├── Caddyfile
├── *.env.template / *.conf
├── docs/
│   ├── selfhosted/
│   │   ├── quickstart-modern.md       # 官方推荐安装与参数核对
│   │   ├── docker-compose-config-cheatsheet.md # 配置文件速查（非脚本）
│   │   ├── legacy-zitadel-path.md     # 历史兼容说明与迁移建议
│   │   └── combined-container-migration-checklist.md # 合并容器迁移检查清单
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
└── 部署说明.md                        # 快速中文入口，保持历史兼容
```

## 六、你要的“跳转入口”（先读哪个）

### 部署链路

- [官方推荐一体化部署说明（新手推荐）](docs/selfhosted/quickstart-modern.md)
- [Zitadel 兼容路径说明](docs/selfhosted/legacy-zitadel-path.md)
- [legacy 到合并容器迁移检查清单](docs/selfhosted/combined-container-migration-checklist.md)
- [服务器端配置速查（无脚本化）](docs/selfhosted/docker-compose-config-cheatsheet.md)

### 场景实践（可直接放给他人）

- [案例 1：用 NetBird 替代 OpenVPN（零信任接入）](docs/cases/01-openvpn-replacement.md)
- [案例 2：企业内网白名单系统接入](docs/cases/02-whitelisted-system-access.md)
- [案例 3：本地办公访问 K8S 集群/Pod 网络](docs/cases/03-kubernetes-connectivity.md)
- [案例 4：NetBird 统一出口与反向代理实践](docs/cases/04-exit-node-and-proxy.md)
- [案例 5：多云内网互通（AWS/GCP/Azure）](docs/cases/05-multi-cloud-connectivity.md)
- [案例 6：官方推荐的安全与高级实践清单](docs/cases/06-official-advanced-scenarios.md)

### 运维

- [防火墙与加固清单](docs/operations/firewall-and-hardening.md)
- [日常运维与故障排查（备份/回滚/升级）](docs/operations/operations-playbook.md)

## 七、基础端口与网络基线

| 协议 | 端口 | 场景 |
| --- | --- | --- |
| TCP | 80 | HTTP/ACME 校验 |
| TCP | 443 | HTTPS 与管理面 |
| UDP | 3478 | STUN |
| UDP | 443 | HTTP/3（按反向代理配置决定，非必需） |

> 新版主线默认最少只需开放 TCP 80、TCP 443、UDP 3478；管理端口务必来源白名单。

## 八、官方资源索引

- 官方文档首页：https://docs.netbird.io/
- 官方客户端安装入口：https://docs.netbird.io/get-started/install
- 自建快速开始（推荐）：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- 自建反向代理说明（官方）：https://docs.netbird.io/selfhosted/reverse-proxy
- 配置文件参考（新部署）：https://docs.netbird.io/selfhosted/configuration-files
- 本地身份管理说明（内置 IdP）：https://docs.netbird.io/selfhosted/identity-providers/local
- 合并容器迁移指南：https://docs.netbird.io/selfhosted/migration/combined-container
- 访问控制文档（官方）：https://docs.netbird.io/manage/access-control/manage-network-access
- 路由网络访问限制（官方）：https://docs.netbird.io/manage/networks/accessing-restricted-domain-resources

## 九、快速对外发布建议

1. 保留本仓库的根目录兼容产物做迁移对照；新用户默认只看 `docs/selfhosted/quickstart-modern.md`。
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

建议将本仓库以 `docs/` 为主入口，根目录文件只保留“入口+兼容历史”，其余实践统一沉淀到 `docs/`。

## 十一、从 legacy 到现代部署的迁移建议（可直接交付给架构组）

- 明确环境属性：新建环境默认按 `getting-started.sh`；已有 Zitadel 环境按运维窗口择机迁移。
- 先做兼容矩阵验证：端口、DNS、策略、路由是否一致。
- 迁移建议顺序：
  1. 先复制旧环境配置清单（compose/network/tls）
  2. 在测试环境跑一条新链路
  3. 验证路由、访问控制、客户端连接
  4. 业务切流后再做正式切换
- 遇到兼容问题优先按文档中的 legacy 路径执行回滚，不要直接回退到未记录状态。

## 十二、官方能力核对（以避免版本偏差）

- 反向代理功能：自托管环境建议优先使用 Traefik 场景，且需确保 `getting-started.sh` 与反向代理能力匹配。
- 新版自建默认会生成 `docker-compose.yml`、`config.yaml`、`dashboard.env`，并按反向代理选项生成额外模板文件；这与旧版的 `management.json` / `relay.env` / `turnserver.conf` 不同。
- 合并容器与历史拆分部署并非完全等价，建议只在新环境采用官方新链路，历史环境保留兼容文档。
- Reverse Proxy、Expose、Browser Client 等能力请始终以官方文档和 release note 为准。
