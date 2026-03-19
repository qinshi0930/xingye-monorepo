#!/bin/bash
# 多应用构建脚本 - 使用 CI 预构建产物打包镜像
# 前置条件: 必须先运行 ./scripts/ci-validate.sh 生成 dist/ 产物
# 用法: ./scripts/build-apps.sh [app1 app2 ...]  默认构建 web

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 检查是否在项目根目录
if [ ! -f "$PROJECT_ROOT/package.json" ] || [ ! -f "$PROJECT_ROOT/pnpm-workspace.yaml" ]; then
    echo "错误: 请在项目根目录运行此脚本"
    exit 1
fi

# 检查构建产物是否存在
if [ ! -d "$PROJECT_ROOT/dist/.next/standalone" ]; then
    echo "错误: 未找到构建产物 (dist/.next/standalone)"
    echo "请先运行: ./scripts/ci-validate.sh"
    exit 1
fi

cd "$PROJECT_ROOT"

APPS=${1:-"web"}  # 默认构建 web，可传入多个: "web admin api"

echo "Building apps: $APPS"

for app in $APPS; do
    echo "Building $app..."
    # 检查 Dockerfile 是否支持该 target
    if ! grep -q "^FROM.*AS $app" Dockerfile; then
        echo "  警告: Dockerfile 中未找到 target '$app'，跳过"
        continue
    fi

    podman build \
        --target $app \
        --build-arg APP_NAME=$app \
        -t xingye-$app:latest \
        . || echo "  警告: $app 构建失败"
done

echo "Build complete!"
