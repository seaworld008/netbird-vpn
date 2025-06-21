# NetBird VPN 官方部署指南

基于 NetBird 官方 `getting-started-with-zitadel.sh` 脚本的标准化部署方案。

## 🎯 关于本项目

本项目提供了 NetBird VPN 的官方标准部署方案，完全基于官方 `getting-started-with-zitadel.sh` 脚本：

- ✅ **官方标准**: 使用 NetBird 官方一键部署脚本
- ✅ **Zitadel 认证**: 集成 Zitadel 身份认证服务  
- ✅ **自动证书**: Let's Encrypt 自动 SSL 证书
- ✅ **完整服务栈**: Management、Dashboard、Signal、Relay、Coturn
- ✅ **生产就绪**: 适合生产环境的配置和安全设置

## 📋 系统要求

### 硬件配置
- **CPU**: 1核心或以上
- **内存**: 2GB 或以上  
- **存储**: 20GB 可用空间
- **网络**: 公网IP和域名

### 软件环境
- **操作系统**: Ubuntu 20.04+ / Debian 11+
- **Docker**: 最新版本 + Docker Compose 插件
- **工具**: `jq`, `curl`
- **域名**: 已解析到服务器IP

### 必需端口列表

根据官方文档，需要开放以下端口：

**TCP 端口:**
- `80` - HTTP (Let's Encrypt验证和重定向)
- `443` - HTTPS (主要访问端口)
- `33073` - Management gRPC (可选，通过Caddy代理)
- `10000` - Signal gRPC (可选，通过Caddy代理)  
- `33080` - Management HTTP (可选，通过Caddy代理)

**UDP 端口:**
- `3478` - STUN/TURN协商
- `49152-65535` - TURN中继端口范围

> **注意**: 在官方脚本部署中，Management、Signal等服务都通过 Caddy 80/443 端口代理访问，因此安全组中只需开放上述端口。

## 🚀 快速部署

### 1. 设置域名
```bash
# 替换为你的实际域名
export NETBIRD_DOMAIN=netbird.example.com
```

### 2. 执行官方部署脚本
```bash
# 方式一：直接执行官方脚本
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh | bash

# 方式二：使用本项目的部署脚本（推荐）
chmod +x deploy.sh
./deploy.sh
```

### 3. 访问管理界面

部署完成后，访问你的域名：
```
https://your-domain.com
```

登录凭据将显示在终端输出中，也会保存在 `.env` 文件中。

## 📱 客户端安装

访问官方客户端下载页面：
```
https://app.netbird.io/install
```

支持的平台：
- **Windows**: .exe 安装包
- **macOS**: .dmg 安装包  
- **Linux**: .deb/.rpm 包或二进制文件
- **Android**: Google Play Store
- **iOS**: App Store

## 🔧 运维管理

### 查看服务状态
```bash
docker compose ps
```

### 查看服务日志
```bash
# 查看所有服务日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f management
docker compose logs -f dashboard
docker compose logs -f caddy
```

### 备份配置

根据官方文档，备份以下文件：
```bash
mkdir backup
cp docker-compose.yml Caddyfile zitadel.env dashboard.env turnserver.conf management.json relay.env zdb.env backup/
```

备份数据库：
```bash
docker compose stop management
docker compose cp -a management:/var/lib/netbird/ backup/
docker compose start management
```

### 升级系统

```bash
# 1. 备份配置和数据（见上方备份步骤）

# 2. 拉取最新镜像
docker compose pull management dashboard signal relay

# 3. 重启服务
docker compose up -d --force-recreate management dashboard signal relay
```

### 完全卸载

```bash
# 停止并删除所有容器和数据卷
docker compose down --volumes

# 删除配置文件
rm -f docker-compose.yml Caddyfile zitadel.env dashboard.env machinekey/zitadel-admin-sa.token turnserver.conf management.json relay.env zdb.env
```

## 🛡️ 安全配置

### 防火墙配置

**Ubuntu UFW:**
```bash
# 允许必需端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw allow 3478/udp
sudo ufw allow 49152:65535/udp

# 启用防火墙
sudo ufw enable
```

**阿里云安全组规则:**

| 序号 | 服务 | 协议 | 端口范围 | 授权对象 | 说明 |
|------|------|------|----------|----------|------|
| 1 | HTTP | TCP | 80/80 | 0.0.0.0/0 | Let's Encrypt验证和重定向 |
| 2 | HTTPS | TCP | 443/443 | 0.0.0.0/0 | 主要访问端口 |
| 3 | HTTP/3 | UDP | 443/443 | 0.0.0.0/0 | QUIC支持（可选） |
| 4 | STUN/TURN | UDP | 3478/3478 | 0.0.0.0/0 | NAT穿透协商 |
| 5 | TURN中继 | UDP | 49152/65535 | 0.0.0.0/0 | 中继端口范围 |
| 6 | TURN TCP | TCP | 3478/3478 | 0.0.0.0/0 | TCP fallback（可选） |
| 7 | Caddy管理 | TCP | 8080/8080 | 你的IP | 管理接口（限制访问） |

## 📁 项目文件说明

根据官方脚本生成的文件结构：

```
netbird-deployment/
├── docker-compose.yml     # Docker Compose 配置
├── Caddyfile             # Caddy 反向代理配置
├── zitadel.env           # Zitadel 环境变量
├── dashboard.env         # Dashboard 环境变量
├── management.json       # Management 服务配置
├── turnserver.conf       # Coturn STUN/TURN 配置
├── relay.env            # Relay 服务环境变量
├── zdb.env              # PostgreSQL 环境变量
├── machinekey/          # Zitadel 机器密钥目录
│   └── zitadel-admin-sa.token
└── .env                 # 管理员登录凭据
```

## 🔍 故障排除

### 常见问题

1. **无法访问管理界面**
   - 检查域名解析是否正确
   - 确认防火墙端口已开放
   - 查看 Caddy 日志：`docker compose logs caddy`

2. **SSL 证书申请失败**
   - 确认域名解析到正确IP
   - 检查80端口是否可访问
   - 查看 Caddy 日志了解详细错误

3. **客户端无法连接**
   - 检查 STUN/TURN 端口是否开放
   - 确认 Coturn 服务运行正常
   - 查看 Management 服务日志

### 获取帮助

- **官方文档**: https://docs.netbird.io/
- **GitHub Issues**: https://github.com/netbirdio/netbird/issues
- **社区支持**: https://netbird.io/community

## 📄 许可证

本项目基于 NetBird 官方脚本，遵循相同的开源许可证。

---

**重要提醒**: 本项目完全基于 NetBird 官方 `getting-started-with-zitadel.sh` 脚本，确保与官方保持一致。如有疑问，请参考官方文档。 