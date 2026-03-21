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
# 使用方式: ./scripts/deploy.sh [environment]
#   environment: 部署环境，默认为 production
#
DEPLOY_DIR="/var/www/xingye-monorepo"
BACKUP_DIR="$DEPLOY_DIR/backups/$(date +%Y%m%d-%H%M%S)"
CONTAINER_NAME="xingye-monorepo"
IMAGE_NAME="xingye-monorepo:latest"
BUILD_CONTAINER=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs/deploy"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
HEALTH_URL="${HEALTH_URL:-http://localhost:8080}"

# 参数解析
ENVIRONMENT="${1:-production}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数 - 同时输出到终端和日志文件
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
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

# 备份函数（包含数据库数据卷）
backup() {
    log "备份当前部署..."
    if [ -d "$DEPLOY_DIR" ] && [ "$(ls -A $DEPLOY_DIR 2>/dev/null)" ]; then
        mkdir -p "$BACKUP_DIR"
        
        # 备份配置文件
        run_cmd "cp '$DEPLOY_DIR/.env' '$BACKUP_DIR/'" "备份 .env" || true
        run_cmd "cp '$DEPLOY_DIR/podman-compose.yml' '$BACKUP_DIR/'" "备份 compose 文件" || true
        run_cmd "cp -r '$DEPLOY_DIR/config' '$BACKUP_DIR/'" "备份 nginx 配置" || true
        
        # 备份数据库数据卷
        log "备份数据库数据卷..."
        run_cmd "podman run --rm -v xingye-monorepo_postgres-data:/data -v '$BACKUP_DIR':/backup alpine tar czf /backup/postgres-data.tar.gz -C /data ." "备份 PostgreSQL 数据" || true
        run_cmd "podman run --rm -v xingye-monorepo_redis-data:/data -v '$BACKUP_DIR':/backup alpine tar czf /backup/redis-data.tar.gz -C /data ." "备份 Redis 数据" || true
        
        # 备份当前运行的镜像标签
        if podman ps -q -f "name=xingye-web" | grep -q .; then
            podman inspect xingye-web --format='{{.Config.Image}}' > "$BACKUP_DIR/image-tag.txt" 2>/dev/null || true
        fi
        
        log "备份完成: $BACKUP_DIR"
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

# 自动发现 dist 中的子应用
# 返回: 空格分隔的应用名称列表
discover_apps() {
    local apps=()
    if [ -d "$PROJECT_DIR/dist" ]; then
        for dir in "$PROJECT_DIR/dist"/*/; do
            if [ -f "$dir/server.js" ]; then
                apps+=("$(basename "$dir")")
            fi
        done
    fi
    echo "${apps[@]}"
}

# 检查构建产物是否存在（dist/ 目录）
# 自动发现所有子应用并检查构建产物完整性
check_build_artifacts() {
    # 自动发现 dist 中的所有子应用
    local apps=($(discover_apps))
    
    if [ ${#apps[@]} -eq 0 ]; then
        log "${YELLOW}错误: 未在 apps/ 目录中找到任何构建产物${NC}"
        log "请先运行 CI 验证生成构建产物:"
        log "  ./scripts/ci-validate.sh"
        return 1
    fi
    
    log "自动发现子应用: ${apps[*]}"
    
    # 检查每个子应用的构建产物完整性
    local missing_apps=()
    for app in "${apps[@]}"; do
        local standalone_dir="$PROJECT_DIR/dist/$app"
        if [ ! -f "$standalone_dir/server.js" ]; then
            missing_apps+=("$app (缺少 server.js)")
        fi
    done
    
    if [ ${#missing_apps[@]} -gt 0 ]; then
        log "${YELLOW}错误: 以下子应用构建产物不完整:${NC}"
        for app in "${missing_apps[@]}"; do
            log "  - $app"
        done
        return 1
    fi
    
    log "所有子应用构建产物检查通过: ${apps[*]}"
    return 0
}

# 主流程
main() {
    log "=== 开始部署 ==="
    log "环境: $ENVIRONMENT"
    log "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 0. 日志管理（仅保留最近5个日志文件）
    manage_logs
    
    # 1. 检查构建产物
    log "步骤 1/5: 检查构建产物..."
    if ! check_build_artifacts; then
        error_exit "未找到构建产物，无法部署"
    fi
    log "构建产物检查通过"

    # 2. 构建生产镜像（调用 build-apps.sh，带版本号）
    log "步骤 2/5: 构建生产镜像..."
    
    # 生成版本号（Git 短哈希 + 时间戳）
    VERSION=$(git rev-parse --short HEAD)-$(date +%Y%m%d-%H%M%S)
    IMAGE_TAG="xingye-web:$VERSION"
    export IMAGE_VERSION="$VERSION"  # 导出给 podman-compose 使用
    log "生成版本号: $VERSION"
    
    # 调用 build-apps.sh 构建镜像
    "$SCRIPT_DIR/build-apps.sh" || error_exit "镜像构建失败"
    
    # 为镜像添加版本标签
    podman tag xingye-web:latest "$IMAGE_TAG"
    log "镜像已标记: $IMAGE_TAG"

    # 3. 备份当前部署
    log "步骤 3/5: 备份当前部署..."
    backup

    # 4. 复制配置文件到部署路径（纯镜像模式，不复制构建产物）
    log "步骤 4/5: 复制配置文件到部署路径 $DEPLOY_DIR..."
    mkdir -p "$DEPLOY_DIR"
    run_cmd "cp podman-compose.yml '$DEPLOY_DIR/'" "复制 podman-compose.yml"
    run_cmd "cp -r config '$DEPLOY_DIR/'" "复制 config 目录"
    run_cmd "cp .env '$DEPLOY_DIR/'" "复制 .env 文件"
    
    # 复制应用环境文件（podman-compose.yml 依赖）
    if [ -f "apps/web/.env.local" ]; then
        mkdir -p "$DEPLOY_DIR/apps/web"
        run_cmd "cp apps/web/.env.local '$DEPLOY_DIR/apps/web/'" "复制 web 环境文件"
    fi
    
    # 保存版本号到部署目录（用于回滚）
    echo "$VERSION" > "$DEPLOY_DIR/.version"
    log "版本号已保存到 .version"

    # 5. 停止旧容器并启动新容器（使用版本号）
    log "步骤 5/5: 停止旧容器并启动新容器..."
    cd "$DEPLOY_DIR"
    
    # 导出 IMAGE_VERSION 供 podman-compose 使用
    export IMAGE_VERSION=$(cat "$DEPLOY_DIR/.version" 2>/dev/null || echo "latest")
    log "使用镜像版本: $IMAGE_VERSION"
    
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
        if podman exec xingye-postgres pg_isready -U "$POSTGRES_USER" > /dev/null 2>&1; then
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
    REDIS_PWD="$REDIS_PASSWORD"
    for i in {1..10}; do
        if podman exec xingye-redis redis-cli -a "$REDIS_PWD" ping 2>/dev/null | grep -q "PONG"; then
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
    # log "  检查应用 HTTP 健康..."
    # sleep 5
    # for i in {1..30}; do
    #     if curl -sf "$HEALTH_URL" > /dev/null; then
    #         log "  ${GREEN}应用健康检查通过${NC}"
    #         break
    #     fi
    #     log "  等待应用服务启动... ($i/30)"
    #     sleep 3
    # done

    # if ! curl -sf "$HEALTH_URL" > /dev/null; then
    #     error_exit "应用健康检查失败"
    # fi

    log "${GREEN}=== 部署成功 ===${NC}"
    log "访问: $HEALTH_URL"
    log "停止: sudo podman-compose -f $DEPLOY_DIR/podman-compose.yml down"
    log "备份位置: $BACKUP_DIR"
}

# 执行主流程
main
