#!/bin/bash
#
# CI 验证脚本 - 部署前全面验证
# ========================================
# 功能：
# - 代码检查 (lint)
# - 类型检查 (type-check)
# - 单元测试
# - 构建应用
# - 集成测试
# - 导出构建产物到 dist/ 目录
#
# 特性：
# - 验证结束后自动销毁 CI 容器，释放系统资源
# - 支持 --skip-cleanup 参数保留容器用于调试
#
# 使用方式: ./scripts/ci-validate.sh [--skip-cleanup]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs/ci"
LOG_FILE="$LOG_DIR/validate-$(date +%Y%m%d-%H%M%S).log"
SKIP_CLEANUP="${1:-false}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log() { echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
success() { log "${GREEN}[SUCCESS] $1${NC}"; }
error() { log "${RED}[ERROR] $1${NC}"; }
info() { log "${BLUE}[INFO] $1${NC}"; }
warn() { log "${YELLOW}[WARN] $1${NC}"; }

# 错误处理
error_exit() {
    error "$1"
    collect_logs
    cleanup
    exit 1
}

# 收集容器日志
collect_logs() {
    info "收集容器日志..."
    {
        echo "=== Validator 容器日志 ==="
        podman logs xingye-ci-validator 2>&1 || echo "无法获取 validator 日志"
        echo ""
        echo "=== Redis 容器日志 ==="
        podman logs xingye-ci-redis 2>&1 || echo "无法获取 redis 日志"
        echo ""
        echo "=== PostgreSQL 容器日志 ==="
        podman logs xingye-ci-postgres 2>&1 || echo "无法获取 postgres 日志"
    } >> "$LOG_FILE" 2>&1
}

# 日志管理：仅保留最近的5个日志文件
manage_logs() {
    local max_logs=5
    local log_count

    log_count=$(ls -1 "$LOG_DIR"/validate-*.log 2>/dev/null | wc -l)

    if [ "$log_count" -gt "$max_logs" ]; then
        info "日志管理: 保留最近 $max_logs 个日志文件，删除旧的..."
        ls -1t "$LOG_DIR"/validate-*.log | tail -n +$((max_logs + 1)) | xargs -r rm -f
        info "日志管理: 已清理旧日志文件"
    fi
}

# 强制销毁 CI 容器（确保资源释放）
destroy_ci_containers() {
    info "强制销毁 CI 容器..."

    # 停止并删除 compose 管理的容器
    cd "$PROJECT_ROOT"
    podman-compose -f podman-compose.ci.yml down -v --remove-orphans 2>/dev/null || true

    # 强制删除可能残留的容器（包括验证容器）
    local containers=("xingye-ci-validator" "xingye-ci-redis" "xingye-ci-postgres")
    for container in "${containers[@]}"; do
        if podman ps -a -q -f "name=$container" | grep -q .; then
            info "  销毁容器: $container"
            podman stop "$container" 2>/dev/null || true
            podman rm -f "$container" 2>/dev/null || true
        fi
    done

    # 清理未使用的网络
    podman network rm ci-network 2>/dev/null || true

    success "CI 容器已销毁，系统资源已释放"
}

# 清理函数
cleanup() {
    if [ "$SKIP_CLEANUP" = "--skip-cleanup" ]; then
        warn "跳过清理（调试模式）"
        return
    fi

    info "清理验证环境..."
    destroy_ci_containers
    info "清理完成"
}

# 导出构建产物到宿主机
export_build_artifacts() {
    info "导出构建产物到宿主机..."

    # 创建宿主机 dist 目录
    mkdir -p "$PROJECT_ROOT/dist"

    # ============================================
    # 当前: 仅导出 web 应用构建产物
    # ============================================
    # 从验证容器复制构建产物
    if podman cp xingye-ci-validator:/app/dist/. "$PROJECT_ROOT/dist/" 2>/dev/null; then
        success "构建产物已导出到: $PROJECT_ROOT/dist/"
        # 显示导出内容
        info "导出内容:"
        ls -la "$PROJECT_ROOT/dist/" | tail -n +2 | while read line; do
            info "  $line"
        done
    else
        warn "无法从容器导出构建产物，尝试从本地 apps/web/.next 复制..."
        if [ -d "$PROJECT_ROOT/apps/web/.next" ]; then
            mkdir -p "$PROJECT_ROOT/dist/.next"
            cp -r "$PROJECT_ROOT/apps/web/.next/standalone" "$PROJECT_ROOT/dist/.next/" 2>/dev/null || true
            cp -r "$PROJECT_ROOT/apps/web/.next/static" "$PROJECT_ROOT/dist/.next/" 2>/dev/null || true
            cp -r "$PROJECT_ROOT/apps/web/public" "$PROJECT_ROOT/dist/" 2>/dev/null || true
            success "构建产物已从本地复制到: $PROJECT_ROOT/dist/"
        else
            error "未找到构建产物，部署可能失败"
            return 1
        fi
    fi

    # ============================================
    # 多应用支持占位 - Admin 构建产物导出
    # ============================================
    # TODO: 当 admin 应用需要独立部署时，取消注释以下代码
    # info "导出 admin 构建产物..."
    # mkdir -p "$PROJECT_ROOT/dist/admin"
    # if [ -d "$PROJECT_ROOT/apps/admin/.next" ]; then
    #     cp -r "$PROJECT_ROOT/apps/admin/.next/standalone" "$PROJECT_ROOT/dist/admin/.next/" 2>/dev/null || true
    #     cp -r "$PROJECT_ROOT/apps/admin/.next/static" "$PROJECT_ROOT/dist/admin/.next/" 2>/dev/null || true
    #     cp -r "$PROJECT_ROOT/apps/admin/public" "$PROJECT_ROOT/dist/admin/" 2>/dev/null || true
    #     success "admin 构建产物已导出"
    # fi

    # ============================================
    # 多应用支持占位 - API 构建产物导出
    # ============================================
    # TODO: 当 api 应用需要独立部署时，取消注释以下代码
    # info "导出 api 构建产物..."
    # mkdir -p "$PROJECT_ROOT/dist/api"
    # if [ -d "$PROJECT_ROOT/apps/api/.next" ]; then
    #     cp -r "$PROJECT_ROOT/apps/api/.next/standalone" "$PROJECT_ROOT/dist/api/.next/" 2>/dev/null || true
    #     cp -r "$PROJECT_ROOT/apps/api/.next/static" "$PROJECT_ROOT/dist/api/.next/" 2>/dev/null || true
    #     cp -r "$PROJECT_ROOT/apps/api/public" "$PROJECT_ROOT/dist/api/" 2>/dev/null || true
    #     success "api 构建产物已导出"
    # fi
}

# 主流程
main() {
    # 初始化
    mkdir -p "$LOG_DIR"
    cd "$PROJECT_ROOT"

    info "=========================================="
    info "        CI 验证流程开始"
    info "=========================================="
    info "项目目录: $PROJECT_ROOT"
    info "日志文件: $LOG_FILE"
    echo ""

    # 1. 清理旧环境
    info "[准备] 清理旧验证环境..."
    podman-compose -f podman-compose.ci.yml down -v 2>/dev/null || true

    # 2. 日志管理（仅保留最近5个日志文件）
    manage_logs

    # 3. 启动验证
    info "[验证] 启动验证容器..."
    echo ""

    if podman-compose -f podman-compose.ci.yml up --abort-on-container-exit 2>&1 | tee -a "$LOG_FILE"; then
        echo ""
        success "=========================================="
        success "        所有验证通过!"
        success "=========================================="
        EXIT_CODE=0
    else
        echo ""
        error "=========================================="
        error "        验证失败!"
        error "=========================================="
        EXIT_CODE=1
    fi

    # 4. 导出构建产物（仅在验证成功时）
    if [ $EXIT_CODE -eq 0 ]; then
        export_build_artifacts || true
    fi

    # 5. 收集日志
    collect_logs

    # 6. 清理环境
    cleanup

    # 7. 输出结果
    echo ""
    if [ $EXIT_CODE -eq 0 ]; then
        success "验证通过，可以执行部署!"
        echo ""
        echo "部署命令:"
        echo "  ./scripts/deploy.sh production"
        echo ""
        echo "或使用 pnpm:"
        echo "  pnpm deploy:prod"
    else
        error "验证失败，请检查日志:"
        error "  $LOG_FILE"
    fi

    exit $EXIT_CODE
}

# 执行主流程
main
