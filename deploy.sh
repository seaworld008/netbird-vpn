#!/bin/bash

# NetBird VPN 官方部署脚本
# 基于官方 getting-started-with-zitadel.sh 脚本

set -e

echo "🚀 NetBird VPN 官方部署脚本"
echo "=============================================="
echo "基于 NetBird 官方 getting-started-with-zitadel.sh"
echo "包含：Zitadel + Caddy + PostgreSQL + 完整 NetBird 栈"
echo ""

# 检查环境变量
if [ -z "$NETBIRD_DOMAIN" ]; then
    echo "❌ 请设置 NETBIRD_DOMAIN 环境变量"
    echo "例如：export NETBIRD_DOMAIN=netbird.example.com"
    exit 1
fi

echo "📋 使用域名: $NETBIRD_DOMAIN"

# 检查必需工具
echo "📋 检查系统要求..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    echo "参考：https://docs.docker.com/engine/install/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq 未安装，请先安装 jq"
    echo "Ubuntu/Debian: sudo apt install jq"
    echo "CentOS/RHEL: sudo yum install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "❌ curl 未安装，请先安装 curl"
    exit 1
fi

echo "✅ 系统要求检查通过"

# 检查是否已存在配置文件
if [ -f "zitadel.env" ] || [ -f "docker-compose.yml" ]; then
    echo ""
    echo "⚠️  检测到已存在的配置文件"
    echo "如果要重新初始化环境，请先清理现有文件："
    echo ""
    echo "  docker compose down --volumes  # 删除所有容器和数据卷"
    echo "  rm -f docker-compose.yml Caddyfile zitadel.env dashboard.env"
    echo "  rm -f management.json relay.env zdb.env turnserver.conf"
    echo "  rm -rf machinekey/"
    echo ""
    echo "⚠️  注意：这将删除数据库中的所有数据，需要重新配置控制台"
    exit 1
fi

echo ""
echo "🔄 下载并执行官方部署脚本..."
echo ""

# 下载并执行官方脚本
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh | bash

echo ""
echo "🎉 部署完成！"
echo ""
echo "访问地址: https://$NETBIRD_DOMAIN"
echo "登录凭据已保存在当前目录的 .env 文件中"
echo ""
echo "客户端下载: https://app.netbird.io/install"
echo ""
echo "📝 配置安全组规则（阿里云格式）："
echo "1. TCP 80/80     - HTTP (Let's Encrypt验证和重定向)"
echo "2. TCP 443/443   - HTTPS (主要访问端口)"
echo "3. UDP 443/443   - HTTP/3 QUIC (可选)"
echo "4. UDP 3478/3478 - STUN/TURN协商"
echo "5. UDP 49152/65535 - TURN中继端口范围"
echo "6. TCP 3478/3478 - TURN TCP fallback (可选)"
echo "7. TCP 8080/8080 - Caddy管理接口 (限制IP访问)" 