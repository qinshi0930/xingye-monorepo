#!/bin/bash
# 多应用构建脚本 - 纯镜像模式（Dockerfile 多阶段构建）
# 用法:
#   ./scripts/build-apps.sh              # 构建默认应用(web)
#   ./scripts/build-apps.sh web admin    # 构建指定应用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 检查是否在项目根目录
if [ ! -f "$PROJECT_ROOT/package.json" ] || [ ! -f "$PROJECT_ROOT/pnpm-workspace.yaml" ]; then
    echo "错误: 请在项目根目录运行此脚本"
    exit 1
fi

cd "$PROJECT_ROOT"

# ========== 自动发现 dist 中的构建产物 ==========
discover_apps() {
    local apps=()
    if [ -d "$PROJECT_ROOT/dist" ]; then
        for dir in "$PROJECT_ROOT/dist"/*/; do
            if [ -f "$dir/server.js" ]; then
                apps+=("$(basename "$dir")")
            fi
        done
    fi
    echo "${apps[@]}"
}

# ========== 检查 Dockerfile 是否支持该应用 ==========
check_dockerfile_target() {
    local app=$1
    if grep -qE "^FROM.*AS\s+$app(\s|$)" "$PROJECT_ROOT/Dockerfile"; then
        return 0
    else
        return 1
    fi
}

# ========== 主流程 ==========
main() {
    # 模式判断: 无参数时构建默认应用(web)，有参数时构建指定应用
    if [ $# -eq 0 ]; then
        # 纯镜像模式: 默认构建 web 应用
        APPS="web"
        echo "纯镜像模式: 构建默认应用 $APPS"
    else
        APPS="$@"
        echo "构建指定应用: $APPS"
    fi

    # 检查每个应用的 Dockerfile 配置
    local missing_targets=()
    for app in $APPS; do
        if ! check_dockerfile_target "$app"; then
            missing_targets+=("$app")
        fi
    done

    # 如果有缺失的 target，中断并提示
    if [ ${#missing_targets[@]} -gt 0 ]; then
        echo ""
        echo "❌ 错误: 以下应用在 Dockerfile 中缺少 target 配置:"
        for app in "${missing_targets[@]}"; do
            echo "   - $app"
        done
        echo ""
        echo "请在 Dockerfile 中添加以下配置:"
        for app in "${missing_targets[@]}"; do
            cat <<EOF

# ============================================
# $app 应用
# ============================================
FROM node:20-alpine AS $app
WORKDIR /app/$app
ENV NODE_ENV=production
COPY dist/$app/ ./
EXPOSE 3000
CMD ["node", "server.js"]
EOF
        done
        echo ""
        exit 1
    fi

    # 执行构建
    echo ""
    for app in $APPS; do
        echo "🔨 构建 $app..."
        podman build \
            --target "$app" \
            -t "xingye-$app:latest" \
            . || echo "⚠️  警告: $app 构建失败"
    done

    echo ""
    echo "✅ 构建完成!"
}

main "$@"
