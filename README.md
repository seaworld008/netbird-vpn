# NetBird VPN 自托管部署包（PostgreSQL版本）

基于官方文档标准化的 NetBird VPN 自托管部署方案，使用 PostgreSQL 数据库替代默认的 SQLite，适用于生产环境。

## 🎯 项目特点

- ✅ **官方文档兼容**: 严格遵循 NetBird 官方环境变量和配置规范
- ✅ **PostgreSQL 数据库**: 使用 PostgreSQL 16 替代 SQLite，提供更好的性能和可靠性
- ✅ **完整服务栈**: 包含 Management、Dashboard、Signal、Relay、Coturn 全套服务
- ✅ **一键部署**: 自动化安装和配置，包含防火墙设置
- ✅ **生产就绪**: 数据持久化、健康检查、自动重启配置
- ✅ **灵活配置**: 支持域名和IP访问模式

## 📋 系统要求

### 硬件要求
- **CPU**: 2核心或以上
- **内存**: 4GB 或以上
- **存储**: 20GB 可用空间
- **网络**: 公网IP（本配置预设：120.50.145.50）

### 操作系统
- Ubuntu 24.04 LTS（推荐）
- Ubuntu 22.04 LTS
- 其他 Debian 系发行版

### 网络端口
```
TCP 端口:
- 80    : HTTP（Let's Encrypt验证）
- 443   : HTTPS（管理服务，可选）
- 8080  : Dashboard Web界面
- 10000 : Signal 服务
- 33073 : Management API & gRPC
- 33080 : Relay 服务

UDP 端口:
- 3478        : STUN/TURN
- 49152-65535 : 动态 TURN 端口范围
```

## 🚀 快速部署

### 1. 下载部署包
```bash
# 克隆或下载本仓库到服务器
cd /tmp
# 假设文件已上传到服务器
```

### 2. 执行一键部署
```bash
chmod +x deploy.sh
./deploy.sh
```

### 3. 按提示选择配置
- **域名模式**: 推荐生产环境，支持 HTTPS 和 Let's Encrypt
- **IP模式**: 适合测试环境，使用 HTTP 访问

### 4. 等待部署完成
部署过程约 8-15 分钟，包括：
- 安装 Docker 和依赖
- 配置防火墙
- 启动 PostgreSQL 数据库
- 启动 NetBird 全套服务

## 📁 文件结构

```
/data/netbird/
├── docker-compose.yml      # 主配置文件
├── turnserver.conf         # Coturn STUN/TURN配置
├── deploy.sh              # 一键部署脚本
├── config/
│   └── management.json    # 管理服务配置
├── postgres/              # PostgreSQL 数据目录
├── postgres-init/         # 数据库初始化脚本
├── management/            # 管理服务数据
├── signal/               # 信号服务数据
├── relay/                # 中继服务数据
└── turn/                 # TURN服务数据
```

## 🔧 服务架构

```
┌─────────────────────────────────────────────────────────────┐
│                     NetBird 服务架构                          │
├─────────────────────────────────────────────────────────────┤
│  Dashboard (8080)  ←→  Management (33073)  ←→  PostgreSQL    │
│                   ↓                                         │
│  Signal (10000)   ←→  Relay (33080)       ←→  Coturn (3478) │
└─────────────────────────────────────────────────────────────┘
```

### 服务说明
- **Dashboard**: Web 管理界面
- **Management**: 核心管理服务，连接 PostgreSQL
- **Signal**: 信令服务，协调 P2P 连接
- **Relay**: 中继服务，P2P 失败时的回退
- **Coturn**: STUN/TURN 服务，NAT 穿透
- **PostgreSQL**: 数据库，存储用户、设备、策略等数据

## 🗄️ PostgreSQL 数据库配置

### 数据库信息
```
数据库类型: PostgreSQL 16
数据库名: netbird
用户名: netbird
密码: NetBirdDB2024!
内部端口: 5432
```

### 连接字符串
```
postgres://netbird:NetBirdDB2024!@postgres:5432/netbird?sslmode=disable
```

### 管理命令
```bash
# 连接数据库
docker-compose exec postgres psql -U netbird -d netbird

# 查看数据库状态
docker-compose exec postgres pg_isready -U netbird -d netbird

# 查看数据库大小
docker-compose exec postgres psql -U netbird -d netbird -c "SELECT pg_size_pretty(pg_database_size('netbird'));"
```

## 🎛️ 访问和配置

### Web 管理界面
- **域名模式**: `https://your.domain.com:8080`
- **IP模式**: `http://120.50.145.50:8080`

### 管理 API
- **域名模式**: `https://your.domain.com:33073`
- **IP模式**: `http://120.50.145.50:33073`

### 初始配置步骤
1. 访问 Web 管理界面
2. 创建管理员账户
3. 配置身份提供商（IdP）或使用本地认证
4. 生成 Setup Key
5. 在客户端设备安装和配置 NetBird

## 🔧 维护操作

### 服务管理
```bash
cd /data/netbird

# 查看服务状态
docker-compose ps

# 查看所有日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs management
docker-compose logs postgres
docker-compose logs dashboard

# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart management

# 停止所有服务
docker-compose down

# 启动所有服务
docker-compose up -d
```

### 数据备份
```bash
cd /data/netbird

# 备份数据库
docker-compose exec postgres pg_dump -U netbird netbird > netbird_backup_$(date +%Y%m%d).sql

# 备份配置文件
tar -czf netbird_config_backup_$(date +%Y%m%d).tar.gz \
  docker-compose.yml turnserver.conf config/ postgres-init/

# 完整备份（包含数据）
sudo tar -czf netbird_full_backup_$(date +%Y%m%d).tar.gz \
  --exclude='postgres/pg_wal' \
  /data/netbird/
```

### 数据恢复
```bash
cd /data/netbird

# 恢复数据库
docker-compose exec -T postgres psql -U netbird netbird < netbird_backup_YYYYMMDD.sql

# 恢复配置文件
tar -xzf netbird_config_backup_YYYYMMDD.tar.gz
```

## 📊 监控和日志

### 服务健康检查
```bash
# 检查所有服务状态
docker-compose ps

# 检查数据库连接
docker-compose exec postgres pg_isready -U netbird -d netbird

# 检查管理服务API
curl -f http://localhost:33073/api/status || echo "Management API not ready"

# 检查Dashboard
curl -f http://localhost:8080 || echo "Dashboard not ready"
```

### 日志监控
```bash
# 实时监控所有日志
docker-compose logs -f

# 监控管理服务日志
docker-compose logs -f management

# 查看最近的错误
docker-compose logs --tail=100 | grep -i error

# 查看数据库相关日志
docker-compose logs management | grep -i postgres
```

### 系统资源监控
```bash
# 查看容器资源使用
docker stats

# 查看数据库大小
docker-compose exec postgres psql -U netbird -d netbird -c "
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"

# 查看磁盘使用
du -sh /data/netbird/*
```

## 🛠️ 故障排除

### 常见问题

#### 1. 服务无法启动
```bash
# 检查端口占用
sudo netstat -tlnp | grep -E ':(80|443|3478|8080|10000|33073|33080)'

# 检查防火墙
sudo ufw status

# 检查Docker状态
sudo systemctl status docker
```

#### 2. 数据库连接失败
```bash
# 检查数据库日志
docker-compose logs postgres

# 测试数据库连接
docker-compose exec postgres pg_isready -U netbird -d netbird

# 检查网络连接
docker-compose exec management ping postgres
```

#### 3. Dashboard 无法访问
```bash
# 检查Dashboard日志
docker-compose logs dashboard

# 检查Management服务API
curl -f http://management:33073/api/status

# 验证容器网络
docker network ls
docker network inspect netbird_netbird
```

#### 4. TURN服务问题
```bash
# 检查Coturn日志
docker-compose logs coturn

# 验证STUN/TURN端口
sudo netstat -ulnp | grep 3478
sudo netstat -ulnp | grep 49152

# 测试STUN服务
stunclient 120.50.145.50 3478
```

### 性能优化

#### PostgreSQL 优化
```sql
-- 连接到数据库执行
docker-compose exec postgres psql -U netbird -d netbird

-- 查看连接数
SELECT count(*) FROM pg_stat_activity;

-- 查看慢查询
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC LIMIT 10;

-- 优化配置（在postgres容器中修改postgresql.conf）
-- shared_buffers = 256MB
-- effective_cache_size = 1GB
-- work_mem = 4MB
```

#### 容器资源限制
在 `docker-compose.yml` 中添加资源限制：
```yaml
services:
  management:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

## 🔄 升级指南

### 升级步骤
```bash
cd /data/netbird

# 1. 备份数据
./backup.sh  # 或手动备份

# 2. 停止服务
docker-compose down

# 3. 更新镜像版本（在docker-compose.yml中）
# 修改版本号，如 v0.47.2 -> v0.48.0

# 4. 拉取新镜像
docker-compose pull

# 5. 启动服务
docker-compose up -d

# 6. 检查服务状态
docker-compose ps
docker-compose logs -f
```

## 🔒 安全建议

### 基础安全
- 更改默认密码（数据库、TURN用户等）
- 配置防火墙规则，只开放必要端口
- 启用 HTTPS（使用域名模式）
- 定期更新镜像版本

### 高级安全
- 设置反向代理（Nginx/Traefik）
- 配置 SSL 证书
- 限制管理界面访问IP
- 启用日志审计

## 📞 技术支持

### 官方资源
- [NetBird 官方文档](https://docs.netbird.io/)
- [NetBird GitHub](https://github.com/netbirdio/netbird)
- [NetBird 社区](https://github.com/netbirdio/netbird/discussions)

### 本项目问题
如遇到部署或配置问题，请提供：
1. 操作系统版本
2. 错误日志（`docker-compose logs`）
3. 服务状态（`docker-compose ps`）
4. 网络配置（防火墙、端口等）

---

**注意**: 本配置基于 NetBird v0.47.2 版本，使用前请确认版本兼容性。 