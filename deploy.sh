#!/usr/bin/env bash

# NetBird 部署脚本（兼容入口）
# 团队标准流程是：执行官方脚本生成基线，再只改配置文件。
# 此脚本仅用于 legacy 场景下的兼容入口。
# - 推荐：getting-started.sh（默认）
# - 历史兼容：getting-started-with-zitadel.sh（通过 NETBIRD_USE_ZITADEL 开关）

set -euo pipefail

if [ -z "${NETBIRD_DOMAIN:-}" ]; then
    echo "❌ 请先设置 NETBIRD_DOMAIN"
    echo "示例：export NETBIRD_DOMAIN=netbird.example.com"
    exit 1
fi

echo "🚀 NetBird 部署脚本（官方对齐）"
echo "================================================"
echo "域名：$NETBIRD_DOMAIN"
echo ""

if [ "${NETBIRD_USE_ZITADEL:-0}" = "1" ] || [ "${NETBIRD_SCRIPT_MODE:-}" = "legacy" ] || [ "${NETBIRD_SCRIPT_MODE:-}" = "zitadel" ]; then
    SCRIPT="getting-started-with-zitadel.sh"
    echo "🧭 将使用 legacy 脚本：$SCRIPT"
else
    SCRIPT="getting-started.sh"
    echo "🧭 将使用官方推荐脚本：$SCRIPT"
fi

echo "📋 检查系统要求..."

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "❌ curl 未安装，请先安装 curl"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq 未安装，请先安装 jq"
    echo "Ubuntu/Debian: sudo apt install jq"
    echo "CentOS/RHEL: sudo yum install jq"
    exit 1
fi

echo "✅ 基础环境检查通过"

echo ""
echo "🔄 下载并执行：${SCRIPT}"
echo ""
curl -fsSL "https://github.com/netbirdio/netbird/releases/latest/download/${SCRIPT}" | bash

echo ""
echo "🎉 执行完成"

echo ""
echo "访问地址： https://$NETBIRD_DOMAIN"
echo "客户端下载： https://app.netbird.io/install"

echo "⚠️ 提示：如果你在使用 legacy 模式，建议仅在已有 Zitadel 体系时启用"
