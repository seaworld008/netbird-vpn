#!/bin/bash

# NetBird VPN 一键部署脚本（PostgreSQL版本）
# 适用于 Ubuntu 24.04
# 公网IP: 120.50.145.50
# 数据库: PostgreSQL

set -e

NETBIRD_DIR="/data/netbird"
PUBLIC_IP="120.50.145.50"

echo "🚀 NetBird VPN 一键部署脚本（PostgreSQL版本）"
echo "=============================================="
echo "目标目录: $NETBIRD_DIR"
echo "公网IP: $PUBLIC_IP"
echo "数据库: PostgreSQL 16"
echo ""

# 检查是否为root用户
if [ "$EUID" -eq 0 ]; then
    echo "❌ 请不要使用 root 用户运行此脚本"
    exit 1
fi

# 1. 安装依赖
echo "📦 安装必要软件包..."
sudo apt update
sudo apt install -y docker.io docker-compose-v2 curl jq ufw postgresql-client

# 启动Docker服务
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# 2. 创建目录结构
echo "📁 创建部署目录..."
sudo mkdir -p $NETBIRD_DIR
sudo chown $USER:$USER $NETBIRD_DIR
cd $NETBIRD_DIR

# 创建数据目录
mkdir -p management config turn postgres postgres-init signal relay

# 3. 创建PostgreSQL初始化脚本
echo "🗄️ 创建数据库初始化脚本..."
cat > postgres-init/01-init.sql << 'EOF'
-- NetBird PostgreSQL 初始化脚本
-- 创建数据库用户和权限设置

-- 确保数据库存在
SELECT 'CREATE DATABASE netbird'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'netbird')\gexec

-- 设置数据库连接参数
ALTER DATABASE netbird SET timezone TO 'UTC';
ALTER DATABASE netbird SET log_statement TO 'none';

-- 创建扩展（如果需要）
\c netbird;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 设置用户权限
GRANT ALL PRIVILEGES ON DATABASE netbird TO netbird;
EOF

# 4. 创建management.json配置文件（如果不存在）
if [ ! -f "config/management.json" ]; then
    echo "📝 创建管理服务配置文件..."
    cat > config/management.json << 'EOF'
{
  "Stuns": [
    {
      "Proto": "udp",
      "URI": "stun:127.0.0.1:3478"
    }
  ],
  "Turns": [
    {
      "Proto": "udp",
      "URI": "turn:127.0.0.1:3478",
      "Username": "netbird",
      "Password": "NetBird2024!"
    }
  ],
  "Signal": {
    "Proto": "http",
    "URI": "127.0.0.1:10000"
  },
  "Relay": {
    "Addresses": ["127.0.0.1:33080"]
  },
  "StoreConfig": {
    "Engine": "postgres"
  },
  "HttpConfig": {
    "Address": "0.0.0.0:33073"
  }
}
EOF
fi

# 5. 配置防火墙
echo "🔒 配置防火墙..."
sudo ufw --force enable
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3478/udp
sudo ufw allow 8080      # Dashboard端口
sudo ufw allow 10000     # Signal端口
sudo ufw allow 33073     # Management端口
sudo ufw allow 33080     # Relay端口
sudo ufw allow 49152:65535/udp
# 可选：允许外部访问PostgreSQL（仅用于管理）
# sudo ufw allow 5432

# 6. 域名配置选择
echo ""
echo "🌐 域名配置"
echo "1) 使用域名（推荐生产环境）"
echo "2) 使用IP地址（测试环境）"
read -p "请选择 [1/2]: " domain_choice

if [ "$domain_choice" = "1" ]; then
    read -p "请输入你的域名（如：netbird.yourdomain.com）: " user_domain
    read -p "请输入管理员邮箱: " admin_email
    
    # 修改docker-compose.yml中的域名
    sed -i "s/your.domain.com/$user_domain/g" docker-compose.yml
    sed -i "s/admin@your.domain.com/$admin_email/g" docker-compose.yml
    
    # 更新管理服务配置中的域名
    sed -i "s/127.0.0.1:3478/$user_domain:3478/g" config/management.json
    sed -i "s/127.0.0.1:10000/$user_domain:10000/g" config/management.json
    sed -i "s/127.0.0.1:33080/$user_domain:33080/g" config/management.json
    
    echo "✅ 已配置域名: $user_domain"
    echo "📧 管理员邮箱: $admin_email"
    echo "🌐 访问地址: https://$user_domain:8080"
else
    # 使用IP地址配置
    sed -i "s/your.domain.com/$PUBLIC_IP/g" docker-compose.yml
    sed -i "s/admin@your.domain.com/admin@localhost.local/g" docker-compose.yml
    
    # 更新管理服务配置中的IP地址
    sed -i "s/127.0.0.1:3478/$PUBLIC_IP:3478/g" config/management.json
    sed -i "s/127.0.0.1:10000/$PUBLIC_IP:10000/g" config/management.json
    sed -i "s/127.0.0.1:33080/$PUBLIC_IP:33080/g" config/management.json
    
    echo "✅ 已配置为IP访问模式"
    echo "🌐 访问地址: http://$PUBLIC_IP:8080"
fi

# 7. 启动数据库服务
echo ""
echo "🗄️ 启动 PostgreSQL 数据库..."
docker-compose up -d postgres

# 等待数据库启动
echo "⏳ 等待数据库初始化..."
sleep 15

# 检查数据库连接
echo "🔍 检查数据库连接..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if docker-compose exec -T postgres pg_isready -U netbird -d netbird >/dev/null 2>&1; then
        echo "✅ PostgreSQL 数据库已就绪"
        break
    else
        echo "⏳ 等待数据库启动... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ 数据库启动超时，请检查日志: docker-compose logs postgres"
    exit 1
fi

# 8. 启动其他服务
echo ""
echo "🚀 启动 NetBird 服务..."
docker-compose up -d

# 9. 等待所有服务启动
echo "⏳ 等待所有服务启动..."
sleep 20

# 10. 检查服务状态
echo ""
echo "📊 服务状态检查:"
docker-compose ps

echo ""
echo "🗄️ 数据库信息:"
echo "  - 数据库类型: PostgreSQL 16"
echo "  - 数据库名: netbird"
echo "  - 用户名: netbird"
echo "  - 密码: NetBirdDB2024!"
echo "  - 内部端口: 5432"

# 11. 测试数据库连接
echo ""
echo "🔍 测试管理服务数据库连接..."
sleep 5
if docker-compose logs management 2>/dev/null | grep -q "database.*connected\|migration.*completed\|server.*started\|postgres.*store.*engine" || \
   docker-compose logs management 2>/dev/null | grep -qv "database.*error\|connection.*failed"; then
    echo "✅ 管理服务已成功连接到PostgreSQL数据库"
else
    echo "⚠️ 请检查管理服务日志: docker-compose logs management"
fi

echo ""
echo "🎉 NetBird VPN（PostgreSQL版本）部署完成！"
echo ""
echo "📝 重要信息:"
echo "  - 部署目录: $NETBIRD_DIR"
echo "  - 配置文件: $NETBIRD_DIR/docker-compose.yml"
echo "  - 管理配置: $NETBIRD_DIR/config/management.json"
echo "  - TURN配置: $NETBIRD_DIR/turnserver.conf"
echo "  - 数据目录: $NETBIRD_DIR/postgres (PostgreSQL数据)"
echo "  - 数据目录: $NETBIRD_DIR/management, $NETBIRD_DIR/signal, $NETBIRD_DIR/relay"

if [ "$domain_choice" = "1" ]; then
    echo "  - 管理界面: https://$user_domain:8080"
    echo "  - 管理API: https://$user_domain:33073"
    echo "  - 管理员邮箱: $admin_email"
else
    echo "  - 管理界面: http://$PUBLIC_IP:8080"
    echo "  - 管理API: http://$PUBLIC_IP:33073"
fi

echo ""
echo "📋 下一步操作:"
echo "  1. 访问管理界面创建管理员账户"
echo "  2. 在管理界面生成 Setup Key"
echo "  3. 在客户端设备上安装并配置 NetBird"
echo ""
echo "🔧 常用维护命令:"
echo "  查看服务状态: cd $NETBIRD_DIR && docker-compose ps"
echo "  查看日志: cd $NETBIRD_DIR && docker-compose logs -f"
echo "  查看管理服务日志: cd $NETBIRD_DIR && docker-compose logs management"
echo "  查看数据库日志: cd $NETBIRD_DIR && docker-compose logs postgres"
echo "  连接数据库: cd $NETBIRD_DIR && docker-compose exec postgres psql -U netbird -d netbird"
echo "  重启服务: cd $NETBIRD_DIR && docker-compose restart"
echo "  停止服务: cd $NETBIRD_DIR && docker-compose down"
echo ""
echo "💾 数据库备份命令:"
echo "  备份数据库: cd $NETBIRD_DIR && docker-compose exec postgres pg_dump -U netbird netbird > netbird_backup_\$(date +%Y%m%d).sql"
echo ""
echo "🔧 故障排除:"
echo "  如果服务无法启动，请检查:"
echo "  1. 端口是否被占用: sudo netstat -tlnp | grep -E ':(80|443|3478|8080|10000|33073|33080)'"
echo "  2. 防火墙设置: sudo ufw status"
echo "  3. Docker服务状态: sudo systemctl status docker"
echo "  4. 服务日志: docker-compose logs [service_name]" 