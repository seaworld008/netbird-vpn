# NetBird 自建部署与实践手册

这个仓库面向想要自建 NetBird 的团队和个人，重点解决三件事：

- 如何按官方脚本快速完成部署
- 如何在 `docker-compose` 场景下理解和修改配置
- 如何把 NetBird 用到真实业务场景里，而不是只停留在“安装成功”

本仓库的定位很明确：

- 服务端以官方脚本生成结果为准
- 服务端部署方式统一按 `docker-compose`
- 文档重点放在“配置说明 + 场景落地 + 运维说明”

## 一、快速开始

### 1. 准备域名

NetBird 自建主线部署必须使用公网域名。

要求：

- 域名必须能解析到你的服务器公网 IP
- 官方自建 Quickstart 以域名为前提，不适合“只有公网 IP、没有域名”的场景
- 如果你在中国大陆面向公网使用，建议使用已备案域名，否则 HTTPS 证书签发和访问链路可能失败

```bash
export NETBIRD_DOMAIN=netbird.example.com
```

### 2. 执行官方脚本

```bash
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh | bash
```

### 3. 首次打开管理界面

```text
https://netbird.example.com
```

新版官方主线默认会进入 `/setup` 页面，由你自己创建第一个管理员账号。

客户端下载入口：

```text
https://docs.netbird.io/get-started/install
```

## 二、这个仓库能帮你什么

如果你已经按官方脚本完成部署，这个仓库主要帮你补齐下面这些内容：

- 服务端配置文件该怎么看、该改哪些
- 阿里云安全组应该怎么开
- 用 NetBird 替代 OpenVPN 的具体做法
- 企业白名单系统怎么接入
- K8S 集群、Pod 网段、本地办公网络怎么打通
- 多云内网互通怎么落地
- Exit Node 和 Reverse Proxy 这些能力什么时候用、怎么配

## 三、推荐阅读顺序

### 部署

- [官方部署说明（新手优先）](docs/selfhosted/quickstart-modern.md)
- [服务器端配置速查](docs/selfhosted/docker-compose-config-cheatsheet.md)

### 场景案例

- [案例 1：用 NetBird 替代 OpenVPN](docs/cases/01-openvpn-replacement.md)
- [案例 2：企业内网白名单系统接入](docs/cases/02-whitelisted-system-access.md)
- [案例 3：本地办公打通云上 K8S 集群网络](docs/cases/03-kubernetes-connectivity.md)
- [案例 4：统一出口与代理发布入口](docs/cases/04-exit-node-and-proxy.md)
- [案例 5：打通多云内网](docs/cases/05-multi-cloud-connectivity.md)
- [案例 6：官方推荐的高级最佳实践合集](docs/cases/06-official-advanced-scenarios.md)

### 运维

- [阿里云安全组与端口说明](docs/operations/firewall-and-hardening.md)
- [日常运维与故障排查](docs/operations/operations-playbook.md)

## 四、基础端口说明

NetBird 主线部署里，最常用的对外端口如下：

| 协议 | 端口 | 作用 |
| --- | --- | --- |
| TCP | 80 | HTTP、证书申请、跳转 |
| TCP | 443 | Dashboard、管理入口、Web 登录 |
| UDP | 3478 | STUN，用于 NAT 探测和协商连接 |
| UDP | 443 | 可选，仅在启用 HTTP/3 时使用 |

如果你是第一次部署，至少先确保：

- `80/tcp`
- `443/tcp`
- `3478/udp`

这三条已放通。

## 五、阿里云安全组怎么开

如果你使用阿里云 ECS，安全组最少添加下面几条“入方向”规则：

| 方向 | 协议 | 端口范围 | 授权对象 | 作用 |
| --- | --- | --- | --- | --- |
| 入方向 | TCP | 80/80 | `0.0.0.0/0` | 证书申请、HTTP 跳转 |
| 入方向 | TCP | 443/443 | `0.0.0.0/0` | Dashboard 和 HTTPS 管理入口 |
| 入方向 | UDP | 3478/3478 | `0.0.0.0/0` | STUN |
| 入方向 | UDP | 443/443 | `0.0.0.0/0` | 可选，HTTP/3 |

新手最容易漏掉的是：

- 只开了 `443/tcp`，没开 `3478/udp`
- 域名解析好了，但 `80/tcp` 没开，导致证书失败

更详细的填写说明见：

- [阿里云安全组与端口说明](docs/operations/firewall-and-hardening.md)

## 六、域名要求

这是自建主线里最容易被忽略的一点：

- 你必须准备一个公网域名
- 这个域名必须提前解析到服务器公网 IP
- 如果没有域名，官方 Quickstart 主线通常无法正常完成 TLS 和 Web 登录链路

如果你在中国大陆使用：

- 建议直接使用已备案域名
- 否则即使服务启动，外部用户访问也可能因为域名或证书链路问题而不稳定

这不是为了“写得规范”，而是为了让控制台、认证、HTTPS 和后续场景文档都能稳定工作

## 七、仓库结构

```text
.
├── README.md
├── 部署说明.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
└── docs/
    ├── selfhosted/
    │   ├── quickstart-modern.md
    │   └── docker-compose-config-cheatsheet.md
    ├── cases/
    │   ├── 01-openvpn-replacement.md
    │   ├── 02-whitelisted-system-access.md
    │   ├── 03-kubernetes-connectivity.md
    │   ├── 04-exit-node-and-proxy.md
    │   ├── 05-multi-cloud-connectivity.md
    │   └── 06-official-advanced-scenarios.md
    └── operations/
        ├── firewall-and-hardening.md
        └── operations-playbook.md
```

## 八、官方文档入口

- 官方文档首页：https://docs.netbird.io/
- 官方客户端安装入口：https://docs.netbird.io/get-started/install
- 自建快速开始：https://docs.netbird.io/selfhosted/selfhosted-quickstart
- 自建反向代理说明：https://docs.netbird.io/selfhosted/reverse-proxy
- 配置文件参考：https://docs.netbird.io/selfhosted/configuration-files
- 本地身份管理说明：https://docs.netbird.io/selfhosted/identity-providers/local
- 访问控制文档：https://docs.netbird.io/manage/access-control/manage-network-access
- 路由网络访问限制：https://docs.netbird.io/manage/networks/accessing-restricted-domain-resources

## 九、仓库说明

- [文档目录索引](docs/README.md)
- [开源协作说明](CONTRIBUTING.md)
- [安全响应流程](SECURITY.md)
- [版本变更记录](CHANGELOG.md)
