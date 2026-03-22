#!/bin/bash

# Next Fullstack Template 安装脚本
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/qinshi0930/next-fullstack-template/main/scripts/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/qinshi0930/next-fullstack-template/main/scripts/install.sh | bash -s -- my-project

set -e

REPO_URL="https://github.com/qinshi0930/xingye-monorepo.git"
DEFAULT_PROJECT_NAME="my-app"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}$1${NC}\n${BOLD}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"; }

# 显示帮助
show_help() {
    cat << EOF
${BOLD}Next Fullstack Template 安装脚本${NC}

使用方法:
  curl -fsSL https://raw.githubusercontent.com/qinshi0930/next-fullstack-template/main/scripts/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/qinshi0930/next-fullstack-template/main/scripts/install.sh | bash -s -- <project-name>

参数:
  project-name    项目名称（默认: my-cms-app）

选项:
  -h, --help      显示帮助信息
  --skip-install  跳过依赖安装
  --skip-git      跳过 git 初始化

示例:
  # 使用默认名称
  curl -fsSL .../install.sh | bash

  # 指定项目名称
  curl -fsSL .../install.sh | bash -s -- my-blog

  # 跳过依赖安装（适合 CI 环境）
  curl -fsSL .../install.sh | bash -s -- my-app --skip-install

EOF
}

# 解析参数
PROJECT_NAME=""
SKIP_INSTALL=false
SKIP_GIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --skip-install)
            SKIP_INSTALL=true
            shift
            ;;
        --skip-git)
            SKIP_GIT=true
            shift
            ;;
        -*)
            error "未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
        *)
            if [[ -z "$PROJECT_NAME" ]]; then
                PROJECT_NAME="$1"
            fi
            shift
            ;;
    esac
done

# 如果没有提供项目名称，询问用户
if [[ -z "$PROJECT_NAME" ]]; then
    echo -n "请输入项目名称 (默认: $DEFAULT_PROJECT_NAME): "
    read -r PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}
fi

# 验证项目名称
if ! [[ "$PROJECT_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    error "项目名称格式无效"
    echo "项目名称必须:"
    echo "  - 以小写字母或数字开头"
    echo "  - 只能包含小写字母、数字和连字符"
    echo "  - 不能以连字符开头或结尾"
    exit 1
fi

# 检查目录是否存在
if [[ -d "$PROJECT_NAME" ]]; then
    error "目录 '$PROJECT_NAME' 已存在"
    exit 1
fi

header "🚀 Next Fullstack Template"
log "正在创建项目: ${BOLD}$PROJECT_NAME${NC}"

# 检查依赖
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# 生成随机密码
generate_password() {
    if check_dependency openssl; then
        openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
    else
        # 备用方案
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1
    fi
}

# 克隆模板
log "正在下载模板..."
if check_dependency git; then
    git clone --depth 1 "$REPO_URL" "$PROJECT_NAME" 2>/dev/null || {
        error "克隆仓库失败"
        echo "请检查网络连接或仓库地址: $REPO_URL"
        exit 1
    }
else
    error "未找到 git，请安装 git 后重试"
    exit 1
fi

# 进入项目目录
cd "$PROJECT_NAME"

# 移除模板的 git 历史
rm -rf .git

# 更新项目名称
log "配置项目名称..."
sed -i.bak "s/\"name\": \"xingye-monorepo\"/\"name\": \"$PROJECT_NAME\"/" package.json && rm -f package.json.bak

# 更新容器名称
if [[ -f "podman-compose.yml" ]]; then
    sed -i.bak "s/xingye-monorepo/$PROJECT_NAME/g" podman-compose.yml && rm -f podman-compose.yml.bak
    sed -i.bak "s/xingye-redis/$PROJECT_NAME-redis/g" podman-compose.yml && rm -f podman-compose.yml.bak
    sed -i.bak "s/xingye-postgres/$PROJECT_NAME-postgres/g" podman-compose.yml && rm -f podman-compose.yml.bak
    sed -i.bak "s/xingye-nginx/$PROJECT_NAME-nginx/g" podman-compose.yml && rm -f podman-compose.yml.bak
fi

if [[ -f "scripts/deploy.sh" ]]; then
    sed -i.bak "s/xingye-monorepo/$PROJECT_NAME/g" scripts/deploy.sh && rm -f scripts/deploy.sh.bak
    sed -i.bak "s/xingye-redis/$PROJECT_NAME-redis/g" scripts/deploy.sh && rm -f scripts/deploy.sh.bak
    sed -i.bak "s/xingye-postgres/$PROJECT_NAME-postgres/g" scripts/deploy.sh && rm -f scripts/deploy.sh.bak
fi

if [[ -f "scripts/ci-validate.sh" ]]; then
    sed -i.bak "s/xingye-ci-validator/$PROJECT_NAME-ci-validator/g" scripts/ci-validate.sh && rm -f scripts/ci-validate.sh.bak
    sed -i.bak "s/xingye-ci-redis/$PROJECT_NAME-ci-redis/g" scripts/ci-validate.sh && rm -f scripts/ci-validate.sh.bak
    sed -i.bak "s/xingye-ci-postgres/$PROJECT_NAME-ci-postgres/g" scripts/ci-validate.sh && rm -f scripts/ci-validate.sh.bak
    sed -i.bak "s/xingye-monorepo_ci-network/${PROJECT_NAME}_ci-network/g" scripts/ci-validate.sh && rm -f scripts/ci-validate.sh.bak
fi

# 生成环境变量
log "生成环境变量..."
if [[ -f ".env.example" ]]; then
    cp .env.example .env
    
    # 生成密码
    REDIS_PASSWORD=$(generate_password)
    POSTGRES_PASSWORD=$(generate_password)
    DB_NAME=$(echo "$PROJECT_NAME" | tr '-' '_')
    
    # 更新 .env 文件
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i.bak "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASSWORD/" .env && rm -f .env.bak
        sed -i.bak "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env && rm -f .env.bak
        sed -i.bak "s/^POSTGRES_USER=.*/POSTGRES_USER=$DB_NAME/" .env && rm -f .env.bak
        sed -i.bak "s/^POSTGRES_DB=.*/POSTGRES_DB=${DB_NAME}_db/" .env && rm -f .env.bak
    else
        # Linux
        sed -i "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASSWORD/" .env
        sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
        sed -i "s/^POSTGRES_USER=.*/POSTGRES_USER=$DB_NAME/" .env
        sed -i "s/^POSTGRES_DB=.*/POSTGRES_DB=${DB_NAME}_db/" .env
    fi
    
    success "环境变量已生成"
else
    warning "未找到 .env.example，跳过环境变量生成"
fi

# 初始化 git
if [[ "$SKIP_GIT" == false ]]; then
    log "初始化 Git 仓库..."
    git init >/dev/null 2>&1
    git add . >/dev/null 2>&1
    git commit -m "chore: initial commit from template" >/dev/null 2>&1
    success "Git 仓库已初始化"
fi

# 安装依赖
if [[ "$SKIP_INSTALL" == false ]]; then
    log "安装依赖..."
    
    # 检查 pnpm
    if check_dependency pnpm; then
        log "使用 pnpm 安装..."
        pnpm install
        success "依赖安装完成"
    # 检查 npm
    elif check_dependency npm; then
        warning "未找到 pnpm，使用 npm 安装..."
        log "建议安装 pnpm: npm install -g pnpm"
        npm install
        success "依赖安装完成"
    else
        warning "未找到包管理器，请手动安装依赖"
        echo "  pnpm install"
        echo "  或"
        echo "  npm install"
    fi
else
    log "跳过依赖安装"
fi

# 完成
header "🎉 项目创建成功！"

echo -e "
${BOLD}项目名称:${NC} $PROJECT_NAME
${BOLD}项目路径:${NC} $(pwd)
"

echo -e "${BOLD}下一步操作:${NC}

  ${CYAN}cd $PROJECT_NAME${NC}

  1. 初始化环境变量:
     ${CYAN}./scripts/init-env.sh${NC}

  2. 启动基础设施（数据库/缓存）:
     ${CYAN}pnpm infra:up${NC}

  3. 生成并推送数据库迁移:
     ${CYAN}pnpm db:generate${NC}
     ${CYAN}pnpm db:push${NC}

  4. 启动开发服务器:
     ${CYAN}pnpm dev:all${NC}

  5. 访问应用:
     ${CYAN}http://localhost:3000${NC} (web)
     ${CYAN}http://localhost:3001${NC} (admin)
     ${CYAN}http://localhost:3002${NC} (api)

${BOLD}生产部署:${NC}

  运行部署脚本:
     ${CYAN}pnpm deploy:prod${NC}

${BOLD}文档:${NC}

  项目指南:    ${CYAN}docs/GUIDE.md${NC}
  部署文档:    ${CYAN}docs/DEPLOY.md${NC}
"

# 检查是否需要提醒安装 pnpm
if ! check_dependency pnpm && [[ "$SKIP_INSTALL" == false ]]; then
    echo -e "${YELLOW}提示:${NC} 建议安装 pnpm 以获得更好的体验"
    echo "  npm install -g pnpm"
    echo ""
fi
