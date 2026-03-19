#!/bin/bash
#
# 部署脚本 - 负责生产环境部署（方案 B：使用 CI 预构建产物）
# ========================================
# 架构设计：
# - 验证+构建：由 ci-validate.sh 统一处理（lint/type-check/test/build）
# - 部署流程：由本脚本负责（检查产物/打包镜像/备份/部署/健康检查）
#
# 前置条件：必须先运行 ci-validate.sh 生成 dist/ 构建产物
#
# 使用方式: ./scripts/deploy.sh [environment] [--skip-validate]
#   environment: 部署环境，默认为 production
#   --skip-validate: 跳过 CI 验证（要求已存在 dist/ 构建产物）
#
DEPLOY_DIR="/var/www/xingye-monorepo"
BACKUP_DIR="$DEPLOY_DIR/backups/$(date +%Y%m%d-%H%M%S)"
CONTAINER_NAME="xingye-monorepo"
IMAGE_NAME="xingye-monorepo:latest"
BUILD_CONTAINER=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
HEALTH_URL="${HEALTH_URL:-http://localhost:8080}"

# 参数解析
ENVIRONMENT="${1:-production}"
SKIP_VALIDATE="${2:-false}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数 - 同时输出到终端和日志文件
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 执行命令并记录完整输出到日志
run_cmd() {
    local cmd="$1"
    local description="${2:-$cmd}"
    log "执行: $description"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 命令: $cmd" >> "$LOG_FILE"
    echo "--- 命令输出开始 ---" >> "$LOG_FILE"
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        echo "--- 命令输出结束 (成功) ---" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        return 0
    else
        local exit_code=$?
        echo "--- 命令输出结束 (失败, 退出码: $exit_code) ---" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        return $exit_code
    fi
}

# 错误处理
error_exit() {
    log "${RED}错误: $1${NC}"
    rollback
    cleanup
    exit 1
}

# 备份函数
backup() {
    log "备份当前部署..."
    if [ -d "$DEPLOY_DIR" ] && [ "$(ls -A $DEPLOY_DIR 2>/dev/null)" ]; then
        mkdir -p "$BACKUP_DIR"
        # 备份构建产物和配置（排除 backups 目录和 nginx 日志）
        run_cmd "bash -c 'cd $DEPLOY_DIR && tar czf $BACKUP_DIR/backup.tar.gz --exclude=backups --exclude=config/nginx/logs .'" "备份部署目录" || true
        # 备份容器状态
        if podman ps -q -f "name=$CONTAINER_NAME" | grep -q .; then
            run_cmd "podman inspect '$CONTAINER_NAME' > '$BACKUP_DIR/container-inspect.json'" "备份容器状态" || true
        fi
        log "备份完成: $BACKUP_DIR/backup.tar.gz"
    else
        log "无现有部署需要备份"
    fi
}

# 回滚函数
rollback() {
    log "${YELLOW}执行回滚...${NC}"
    
    # 停止并删除新容器
    cd "$DEPLOY_DIR" 2>/dev/null
    run_cmd "podman-compose -f podman-compose.yml down" "停止当前容器" || true
    
    # 恢复备份
    if [ -f "$BACKUP_DIR/backup.tar.gz" ]; then
        log "恢复备份..."
        run_cmd "rm -rf '$DEPLOY_DIR'/*" "清理部署目录" || true
        run_cmd "tar xzf '$BACKUP_DIR/backup.tar.gz' -C '$DEPLOY_DIR'" "解压备份" || true
        
        # 尝试重新启动旧容器
        if [ -f "$BACKUP_DIR/container-inspect.json" ]; then
            log "尝试重启旧容器..."
            cd "$DEPLOY_DIR"
            run_cmd "podman-compose -f podman-compose.yml up -d" "重启旧容器" || true
        fi
        log "回滚完成"
    else
        log "无备份可恢复"
    fi
}

# 日志管理：仅保留最近的5个日志文件
manage_logs() {
    local max_logs=5
    local log_count

    log_count=$(ls -1 "$LOG_DIR"/deploy-*.log 2>/dev/null | wc -l)

    if [ "$log_count" -gt "$max_logs" ]; then
        log "日志管理: 保留最近 $max_logs 个部署日志文件，删除旧的..."
        ls -1t "$LOG_DIR"/deploy-*.log | tail -n +$((max_logs + 1)) | xargs -r rm -f
        log "日志管理: 已清理旧日志文件"
    fi
}

# 清理函数
cleanup() {
    log "清理临时资源..."
    if [ -n "$BUILD_CONTAINER" ]; then
        run_cmd "podman rm '$BUILD_CONTAINER' 2>/dev/null" "删除构建容器" || true
    fi
    run_cmd "rm -rf ./.next-export" "删除临时导出目录" || true
    log "清理完成"
}

# 检查 CI 构建产物是否存在
check_build_artifacts() {
    if [ ! -d "$PROJECT_DIR/dist/.next/standalone" ]; then
        log "${YELLOW}警告: 未找到 CI 构建产物 (dist/.next/standalone)${NC}"
        log "请先运行 CI 验证: ./scripts/ci-validate.sh"
        return 1
    fi
    return 0
}

# 主流程
main() {
    log "=== 开始部署 ==="
    log "环境: $ENVIRONMENT"
    log "跳过验证: $SKIP_VALIDATE"

    # 0. 日志管理（仅保留最近5个日志文件）
    manage_logs

    # 1. CI 验证阶段（验证流程由 ci-validate.sh 统一处理，包含构建）
    if [ "$SKIP_VALIDATE" != "true" ]; then
        log "步骤 1/6: 执行 CI 验证（包含构建）..."
        if [ -f "$SCRIPT_DIR/ci-validate.sh" ]; then
            if ! "$SCRIPT_DIR/ci-validate.sh"; then
                error_exit "CI 验证失败，终止部署"
            fi
        else
            log "${YELLOW}警告: ci-validate.sh 不存在，跳过验证${NC}"
        fi
    else
        log "${YELLOW}跳过 CI 验证${NC}"
    fi

    # 2. 检查构建产物
    log "步骤 2/6: 检查 CI 构建产物..."
    if ! check_build_artifacts; then
        if [ "$SKIP_VALIDATE" = "true" ]; then
            error_exit "跳过验证但未找到构建产物，无法部署"
        else
            error_exit "CI 验证后未找到构建产物"
        fi
    fi
    log "构建产物检查通过"

    # 3. 构建生产镜像（使用 CI 预构建产物，仅打包）
    log "步骤 3/6: 构建生产镜像（使用 CI 预构建产物）..."
    run_cmd "podman build -t '$IMAGE_NAME' ." "构建镜像 $IMAGE_NAME" || error_exit "镜像构建失败"

    # 4. 备份当前部署
    log "步骤 4/6: 备份当前部署..."
    backup

    # 5. 复制到部署路径
    log "步骤 5/6: 复制到部署路径 $DEPLOY_DIR..."
    mkdir -p "$DEPLOY_DIR"
    run_cmd "cp -r '$PROJECT_DIR/dist/.next' '$DEPLOY_DIR/'" "复制 .next 到部署目录"
    run_cmd "cp -r '$PROJECT_DIR/dist/public' '$DEPLOY_DIR/'" "复制 public 到部署目录"
    run_cmd "cp package.json pnpm-lock.yaml '$DEPLOY_DIR/'" "复制配置文件"
    run_cmd "cp podman-compose.yml '$DEPLOY_DIR/'" "复制 podman-compose.yml"
    run_cmd "cp -r config '$DEPLOY_DIR/'" "复制 config 目录"
    run_cmd "cp .env '$DEPLOY_DIR/'" "复制 .env 文件"

    # 6. 停止旧容器并启动新容器
    log "步骤 6/6: 停止旧容器并启动新容器..."
    cd "$DEPLOY_DIR"
    run_cmd "podman-compose -f podman-compose.yml down" "停止旧容器" || true
    log "旧容器已停止"
    run_cmd "podman-compose -f podman-compose.yml up -d" "启动新容器" || error_exit "容器启动失败"

    # 加载环境变量并健康检查
    if [ -f "$DEPLOY_DIR/.env" ]; then
        export $(grep -v '^#' "$DEPLOY_DIR/.env" | xargs)
    fi

    # 健康检查
    log "执行健康检查..."

    # 检查 PostgreSQL
    log "  检查 PostgreSQL 状态..."
    for i in {1..30}; do
        if podman exec xingye-monorepo-postgres pg_isready -U "${POSTGRES_USER:-xingye}" > /dev/null 2>&1; then
            log "  ${GREEN}PostgreSQL 就绪${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            log "  ${YELLOW}警告: PostgreSQL 健康检查超时${NC}"
        else
            log "  等待 PostgreSQL 启动... ($i/30)"
            sleep 2
        fi
    done

    # 检查 Redis
    log "  检查 Redis 状态..."
    REDIS_PWD="${REDIS_PASSWORD:-}"
    for i in {1..10}; do
        if podman exec xingye-monorepo-redis redis-cli -a "$REDIS_PWD" ping 2>/dev/null | grep -q "PONG"; then
            log "  ${GREEN}Redis 就绪${NC}"
            break
        fi
        if [ $i -eq 10 ]; then
            log "  ${YELLOW}警告: Redis 健康检查超时${NC}"
        else
            log "  等待 Redis 启动... ($i/10)"
            sleep 1
        fi
    done

    # 检查应用 HTTP 健康
    log "  检查应用 HTTP 健康..."
    sleep 3
    for i in {1..10}; do
        if curl -sf "$HEALTH_URL" > /dev/null; then
            log "  ${GREEN}应用健康检查通过${NC}"
            break
        fi
        log "  等待应用服务启动... ($i/10)"
        sleep 2
    done

    if ! curl -sf "$HEALTH_URL" > /dev/null; then
        error_exit "应用健康检查失败"
    fi

    log "${GREEN}=== 部署成功 ===${NC}"
    log "访问: $HEALTH_URL"
    log "停止: sudo podman-compose -f $DEPLOY_DIR/podman-compose.yml down"
    log "备份位置: $BACKUP_DIR"
}

# 执行主流程
main
