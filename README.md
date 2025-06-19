# NetBird VPN Docker-Compose 部署文档

## 📋 环境信息
- **系统**: Ubuntu 24.04
- **部署目录**: `/data/netbird/`
- **公网IP**: `120.50.145.50`
- **NetBird版本**: `v0.47.2` (当前最新稳定版)

## 🚀 快速部署

### 1. 环境准备

```bash
# 安装 Docker 和 docker-compose
sudo apt update
sudo apt install -y docker.io docker-compose-v2 curl jq
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# 创建部署目录
sudo mkdir -p /data/netbird
sudo chown $USER:$USER /data/netbird
cd /data/netbird
```

### 2. 下载配置文件

将 `docker-compose.yml` 文件保存到 `/data/netbird/` 目录。

### 3. 配置域名（重要）

**方法一：使用域名（推荐）**
```bash
# 修改 docker-compose.yml 中的域名配置
sed -i 's/your.domain.com/你的域名.com/g' docker-compose.yml
sed -i 's/admin@your.domain.com/你的邮箱@domain.com/g' docker-compose.yml
```

**方法二：使用IP地址（简单测试）**
```bash
# 如果没有域名，可以临时使用IP访问（不推荐生产环境）
sed -i 's/NB_MANAGEMENT_LETSENCRYPT_ENABLED=true/NB_MANAGEMENT_LETSENCRYPT_ENABLED=false/g' docker-compose.yml
sed -i 's/your.domain.com/120.50.145.50/g' docker-compose.yml
```

### 4. 启动服务

```bash
cd /data/netbird
docker-compose up -d
```

### 5. 验证部署

```bash
# 查看所有服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

## 🔧 配置说明

### 核心服务端口
- **Web管理界面**: `80/443` (HTTP/HTTPS)
- **信号服务**: `10000` (NetBird内部通信)
- **中继服务**: `33073` (P2P连接失败时的回退)
- **STUN/TURN**: `3478` + `49152-65535/UDP` (NAT穿透)

### 数据持久化目录
```
/data/netbird/
├── management/     # NetBird管理服务数据
├── config/         # NetBird配置文件
├── turn/          # Coturn服务数据
├── postgres/      # PostgreSQL数据库文件（可选）
└── docker-compose.yml
```

### 环境变量说明
| 变量 | 说明 | 默认值 |
|------|------|--------|
| `NB_MANAGEMENT_DOMAIN` | 管理服务域名 | your.domain.com |
| `NB_MANAGEMENT_LETSENCRYPT_ENABLED` | 是否启用自动SSL证书 | true |
| `NB_MANAGEMENT_ADMIN_EMAIL` | 管理员邮箱 | admin@your.domain.com |
| `NB_LOG_LEVEL` | 日志级别 | info |

## 👥 客户端配置

### 1. 访问管理界面
- 域名访问: `https://你的域名.com`
- IP访问: `http://120.50.145.50` (仅测试环境)

### 2. 创建管理员账户
首次访问时使用配置的管理员邮箱注册账户。

### 3. 添加客户端设备
- **方法一**: 在管理界面生成Setup Key，设备使用key加入
- **方法二**: 在管理界面直接邀请用户邮箱

### 4. 客户端安装
- **Linux**: `curl -fsSL https://pkgs.netbird.io/install.sh | sh`
- **Windows**: 下载 `.msi` 安装包
- **macOS**: 下载 `.pkg` 安装包
- **Android/iOS**: 应用商店搜索 "NetBird"

### 5. 客户端连接
```bash
# 使用Setup Key连接
netbird up --setup-key YOUR_SETUP_KEY

# 使用SSO连接
netbird up --management-url https://你的域名.com
```

## 🔧 日常维护

### 服务管理
```bash
cd /data/netbird

# 查看服务状态
docker-compose ps

# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启特定服务
docker-compose restart management

# 查看实时日志
docker-compose logs -f [服务名]
```

### 更新版本
```bash
cd /data/netbird

# 拉取最新镜像
docker-compose pull

# 重启服务应用更新
docker-compose up -d

# 清理旧镜像
docker image prune -f
```

### 数据备份
```bash
# 停止服务
docker-compose down

# 备份数据目录
sudo tar -czf netbird-backup-$(date +%Y%m%d).tar.gz \
  management/ config/ turn/ postgres/

# 恢复数据
sudo tar -xzf netbird-backup-YYYYMMDD.tar.gz

# 启动服务
docker-compose up -d
```

### 监控和故障排除
```bash
# 查看系统资源使用
docker stats

# 查看特定服务日志
docker-compose logs management
docker-compose logs signal
docker-compose logs coturn

# 查看网络连接
ss -tulnp | grep -E "(80|443|3478|10000|33073)"

# 测试STUN服务
echo "测试STUN服务连通性"
nc -u 120.50.145.50 3478 < /dev/null
```

## 🔒 安全配置

### 防火墙设置（Ubuntu UFW）
```bash
# 启用防火墙
sudo ufw enable

# 允许必要端口
sudo ufw allow 22        # SSH
sudo ufw allow 80        # HTTP
sudo ufw allow 443       # HTTPS
sudo ufw allow 3478/udp  # STUN
sudo ufw allow 10000     # Signal
sudo ufw allow 33073     # Relay
sudo ufw allow 49152:65535/udp  # TURN端口范围

# 查看防火墙状态
sudo ufw status
```

### 定期维护任务
```bash
# 创建维护脚本
cat > /data/netbird/maintenance.sh << 'EOF'
#!/bin/bash
cd /data/netbird

echo "$(date): 开始维护任务"

# 清理日志（保留最近7天）
docker system prune -f --filter "until=168h"

# 检查磁盘使用
df -h /data/netbird

# 检查服务状态
docker-compose ps

echo "$(date): 维护任务完成"
EOF

chmod +x /data/netbird/maintenance.sh

# 添加到计划任务（每周执行）
echo "0 2 * * 0 /data/netbird/maintenance.sh >> /var/log/netbird-maintenance.log 2>&1" | sudo crontab -
```

## 📊 性能优化

### 系统调优
```bash
# 优化网络参数
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.udp_mem = 102400 873800 16777216' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Docker资源限制
在 docker-compose.yml 中添加资源限制：
```yaml
services:
  management:
    # ... 其他配置
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'
```

## 🆘 故障排除

### 常见问题

**1. 管理界面无法访问**
```bash
# 检查服务状态
docker-compose ps
# 检查日志
docker-compose logs management
# 检查端口占用
ss -tulnp | grep -E "(80|443)"
```

**2. 客户端无法连接**
```bash
# 检查信号服务
docker-compose logs signal
# 检查防火墙
sudo ufw status
# 测试端口连通性
telnet 120.50.145.50 10000
```

**3. P2P连接失败**
```bash
# 检查TURN服务
docker-compose logs coturn
# 检查UDP端口
nc -u 120.50.145.50 3478 < /dev/null
```

## 📞 技术支持

- **官方文档**: https://docs.netbird.io/
- **GitHub项目**: https://github.com/netbirdio/netbird
- **社区支持**: https://github.com/netbirdio/netbird/discussions

---

## 📝 版本信息

- **文档版本**: 1.0
- **NetBird版本**: v0.47.2
- **更新日期**: 2024年6月
- **适用系统**: Ubuntu 24.04

**注意**: 请定期检查 [NetBird Releases](https://github.com/netbirdio/netbird/releases) 获取最新版本信息。 