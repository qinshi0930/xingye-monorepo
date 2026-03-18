#!/bin/bash

# 配置
DEPLOY_DIR="/var/www/xingye-monorepo"
BACKUP_DIR="$DEPLOY_DIR/backups/$(date +%Y%m%d-%H%M%S)"
CONTAINER_NAME="xingye-monorepo"
IMAGE_NAME="xingye-monorepo:latest"
BUILD_CONTAINER="cms-build-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
mkdir -p "$PROJECT_DIR/logs"
LOG_FILE="$PROJECT_DIR/logs/deploy-$(date +%Y%m%d-%H%M%S).log"
HEALTH_URL="http://localhost:8080"

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

# 清理函数
cleanup() {
    log "清理临时资源..."
    if [ -n "$BUILD_CONTAINER" ]; then
        run_cmd "podman rm '$BUILD_CONTAINER' 2>/dev/null" "删除构建容器" || true
    fi
    run_cmd "rm -rf ./.next-export" "删除临时导出目录" || true
    log "清理完成"
}

# 主流程
main() {
    log "=== 开始部署 ==="
    
    # 1. 构建镜像（测试在构建阶段运行，使用 Mock）
    log "步骤 1/9: 构建镜像..."
    run_cmd "podman build -t '$IMAGE_NAME' ." "构建镜像 $IMAGE_NAME" || error_exit "镜像构建失败"
    
    # 2. 导出构建产物
    log "步骤 2/9: 导出构建产物..."
    run_cmd "podman create --name '$BUILD_CONTAINER' '$IMAGE_NAME'" "创建临时容器"
    mkdir -p ./.next-export
    run_cmd "podman cp '$BUILD_CONTAINER:/app/.next' ./.next-export/" "复制 .next 目录"
    run_cmd "podman cp '$BUILD_CONTAINER:/app/public' ./.next-export/" "复制 public 目录"
    run_cmd "podman rm '$BUILD_CONTAINER'" "删除临时容器"
    BUILD_CONTAINER=""
    
    # 3. 备份当前部署
    log "步骤 3/9: 备份当前部署..."
    backup
    
    # 4. 复制到部署路径
    log "步骤 4/9: 复制到部署路径 $DEPLOY_DIR..."
    mkdir -p "$DEPLOY_DIR"
    run_cmd "cp -r ./.next-export/.next '$DEPLOY_DIR/'" "复制 .next 到部署目录"
    run_cmd "cp -r ./.next-export/public '$DEPLOY_DIR/'" "复制 public 到部署目录"
    run_cmd "cp package.json pnpm-lock.yaml '$DEPLOY_DIR/'" "复制配置文件"
    
    # 5. 复制生产配置文件
    log "步骤 5/9: 复制生产配置文件..."
    run_cmd "cp podman-compose.yml '$DEPLOY_DIR/'" "复制 podman-compose.yml"
    run_cmd "cp -r config '$DEPLOY_DIR/'" "复制 config 目录"
    run_cmd "cp .env '$DEPLOY_DIR/'" "复制 .env 文件"
    
    # 6. 停止旧容器
    log "步骤 6/9: 停止旧容器..."
    cd "$DEPLOY_DIR"
    run_cmd "podman-compose -f podman-compose.yml down" "停止旧容器" || true
    log "旧容器已停止"
    
    # 7. 启动新容器（使用生产配置）
    log "步骤 7/9: 启动新容器..."
    cd "$DEPLOY_DIR"
    run_cmd "podman-compose -f podman-compose.yml up -d" "启动新容器" || error_exit "容器启动失败"
    
    # 8. 健康检查
    log "步骤 8/9: 健康检查..."
    
    # 加载环境变量
    if [ -f "$DEPLOY_DIR/.env" ]; then
        export $(grep -v '^#' "$DEPLOY_DIR/.env" | xargs)
    fi
    
    # 8.1 检查 PostgreSQL
    log "检查 PostgreSQL 状态..."
    for i in {1..30}; do
        if podman exec xingye-monorepo-postgres pg_isready -U "${POSTGRES_USER:-postgres}" > /dev/null 2>&1; then
            log "${GREEN}PostgreSQL 就绪${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            log "${YELLOW}警告: PostgreSQL 健康检查超时${NC}"
        else
            log "等待 PostgreSQL 启动... ($i/30)"
            sleep 2
        fi
    done
    
    # 8.2 检查 Redis
    log "检查 Redis 状态..."
    REDIS_PWD="${REDIS_PASSWORD:-}"
    for i in {1..10}; do
        if podman exec xingye-monorepo-redis redis-cli -a "$REDIS_PWD" ping 2>/dev/null | grep -q "PONG"; then
            log "${GREEN}Redis 就绪${NC}"
            break
        fi
        if [ $i -eq 10 ]; then
            log "${YELLOW}警告: Redis 健康检查超时${NC}"
        else
            log "等待 Redis 启动... ($i/10)"
            sleep 1
        fi
    done
    
    # 8.3 检查应用 HTTP 健康
    sleep 3
    for i in {1..10}; do
        if curl -sf "$HEALTH_URL" > /dev/null; then
            log "${GREEN}应用健康检查通过${NC}"
            break
        fi
        log "等待应用服务启动... ($i/10)"
        sleep 2
    done
    
    if ! curl -sf "$HEALTH_URL" > /dev/null; then
        error_exit "应用健康检查失败"
    fi
    
    # 9. 清理临时文件
    log "清理临时文件..."
    cleanup
    
    log "${GREEN}=== 部署成功 ===${NC}"
    log "访问: $HEALTH_URL"
    log "停止: sudo podman-compose -f $DEPLOY_DIR/podman-compose.yml down"
    log "备份位置: $BACKUP_DIR"
}

# 执行主流程
main
