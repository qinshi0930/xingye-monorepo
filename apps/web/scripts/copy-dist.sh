#!/bin/sh

# 构建产物复制脚本
# 将 web 应用的 standalone 构建产物复制到根目录 dist/web

set -e

# 获取脚本所在目录（兼容 sh）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 获取 web 应用目录
WEB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 获取 monorepo 根目录（通过向上查找 package.json）
ROOT_DIR="$WEB_DIR"
while [ "$ROOT_DIR" != "/" ]; do
    if [ -f "$ROOT_DIR/package.json" ] && [ -f "$ROOT_DIR/pnpm-workspace.yaml" ]; then
        break
    fi
    ROOT_DIR="$(dirname "$ROOT_DIR")"
done

# 定义源目录和目标目录
SOURCE_DIR="$WEB_DIR/.next/standalone/apps/web"
TARGET_DIR="$ROOT_DIR/dist/web"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误: 源目录不存在: $SOURCE_DIR"
    echo "请先执行构建: pnpm --filter web build"
    exit 1
fi

# 创建目标目录
mkdir -p "$TARGET_DIR"

# 复制构建产物
echo "复制构建产物..."
echo "  源目录: $SOURCE_DIR"
echo "  目标目录: $TARGET_DIR"

# 使用 tar 复制（-h 参数跟随软链接，复制实际文件）
# 这比 cp -rL 更可靠，能正确处理嵌套软链接
echo "复制 standalone 构建产物（展开软链接）..."
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cd "$SOURCE_DIR" && tar -cf - --exclude='*.map' . | (cd "$TARGET_DIR" && tar -xhf -)

# 同时复制 static 目录（CSS 等资源）
STATIC_SOURCE="$WEB_DIR/.next/static"
STATIC_TARGET="$TARGET_DIR/.next/static"

if [ -d "$STATIC_SOURCE" ]; then
    echo "复制 static 资源..."
    mkdir -p "$STATIC_TARGET"
    if command -v rsync &> /dev/null; then
        rsync -avL "$STATIC_SOURCE/" "$STATIC_TARGET/"
    else
        cp -rL "$STATIC_SOURCE"/* "$STATIC_TARGET/"
    fi
fi

# 复制 public 目录（静态资源）
PUBLIC_SOURCE="$WEB_DIR/public"
PUBLIC_TARGET="$TARGET_DIR/public"

if [ -d "$PUBLIC_SOURCE" ]; then
    echo "复制 public 资源..."
    mkdir -p "$PUBLIC_TARGET"
    if command -v rsync &> /dev/null; then
        rsync -avL "$PUBLIC_SOURCE/" "$PUBLIC_TARGET/"
    else
        cp -rL "$PUBLIC_SOURCE"/* "$PUBLIC_TARGET/"
    fi
fi

echo "构建产物复制完成: $TARGET_DIR"
