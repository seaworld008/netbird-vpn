#!/bin/bash

# NetBird VPN 一键部署脚本
# 适用于 Ubuntu 24.04
# 公网IP: 120.50.145.50

set -e

NETBIRD_DIR="/data/netbird"
PUBLIC_IP="120.50.145.50"

echo "🚀 NetBird VPN 一键部署脚本"
echo "================================"
echo "目标目录: $NETBIRD_DIR"
echo "公网IP: $PUBLIC_IP"
echo ""

# 检查是否为root用户
if [ "$EUID" -eq 0 ]; then
    echo "❌ 请不要使用 root 用户运行此脚本"
    exit 1
fi

# 1. 安装依赖
echo "📦 安装必要软件包..."
sudo apt update
sudo apt install -y docker.io docker-compose-v2 curl jq ufw

# 启动Docker服务
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# 2. 创建目录结构
echo "📁 创建部署目录..."
sudo mkdir -p $NETBIRD_DIR
sudo chown $USER:$USER $NETBIRD_DIR
cd $NETBIRD_DIR

# 创建数据目录
mkdir -p management config turn postgres

# 3. 配置防火墙
echo "🔒 配置防火墙..."
sudo ufw --force enable
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3478/udp
sudo ufw allow 10000
sudo ufw allow 33073
sudo ufw allow 49152:65535/udp

# 4. 域名配置选择
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
    
    echo "✅ 已配置域名: $user_domain"
    echo "📧 管理员邮箱: $admin_email"
    echo "🌐 访问地址: https://$user_domain"
else
    # 使用IP地址配置
    sed -i 's/NB_MANAGEMENT_LETSENCRYPT_ENABLED=true/NB_MANAGEMENT_LETSENCRYPT_ENABLED=false/g' docker-compose.yml
    sed -i "s/your.domain.com/$PUBLIC_IP/g" docker-compose.yml
    
    echo "✅ 已配置为IP访问模式"
    echo "🌐 访问地址: http://$PUBLIC_IP"
fi

# 5. 启动服务
echo ""
echo "🚀 启动 NetBird 服务..."
docker-compose up -d

# 6. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 7. 检查服务状态
echo ""
echo "📊 服务状态检查:"
docker-compose ps

echo ""
echo "🎉 NetBird VPN 部署完成！"
echo ""
echo "📝 重要信息:"
echo "  - 部署目录: $NETBIRD_DIR"
echo "  - 配置文件: $NETBIRD_DIR/docker-compose.yml"
echo "  - 数据目录: $NETBIRD_DIR/management, $NETBIRD_DIR/config, $NETBIRD_DIR/turn"

if [ "$domain_choice" = "1" ]; then
    echo "  - 管理界面: https://$user_domain"
    echo "  - 管理员邮箱: $admin_email"
else
    echo "  - 管理界面: http://$PUBLIC_IP"
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
echo "  重启服务: cd $NETBIRD_DIR && docker-compose restart"
echo "  停止服务: cd $NETBIRD_DIR && docker-compose down"
echo ""
echo "📚 详细文档: $NETBIRD_DIR/README.md"

# 检查是否需要重新登录以获取Docker权限
if ! groups $USER | grep -q docker; then
    echo ""
    echo "⚠️  注意: 需要重新登录以获取Docker权限，或运行:"
    echo "   newgrp docker"
fi 