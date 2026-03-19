#!/bin/bash

# 初始化环境变量脚本
# 检查 .env 文件中的 redis_password 和 postgres_password 字段
# 如果为空，则生成随机密码

set -e

ENV_FILE=".env"

# 生成随机密码的函数
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

# 检查 .env 文件是否存在
if [ ! -f "$ENV_FILE" ]; then
    echo "错误: $ENV_FILE 文件不存在"
    exit 1
fi

# 检查并生成 REDIS_PASSWORD
REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)
if [ -z "$REDIS_PASSWORD" ]; then
    NEW_REDIS_PASSWORD=$(generate_password)
    sed -i "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$NEW_REDIS_PASSWORD/" "$ENV_FILE"
    echo "已生成 REDIS_PASSWORD"
else
    echo "REDIS_PASSWORD 已存在，跳过生成"
fi

# 检查并生成 POSTGRES_PASSWORD
POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)
NEW_POSTGRES_PASSWORD=""
if [ -z "$POSTGRES_PASSWORD" ]; then
    NEW_POSTGRES_PASSWORD=$(generate_password)
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$NEW_POSTGRES_PASSWORD/" "$ENV_FILE"
    echo "已生成 POSTGRES_PASSWORD"
else
    echo "POSTGRES_PASSWORD 已存在，跳过生成"
fi

# 生成 DATABASE_URL 的函数
generate_database_url() {
    local host="${POSTGRES_HOST:-localhost}"
    local port="${POSTGRES_PORT:-5432}"
    local user="${POSTGRES_USER:-xingye}"
    local password="$1"
    local db="${POSTGRES_DB:-xingye_db}"
    echo "postgresql://${user}:${password}@${host}:${port}/${db}?sslmode=disable"
}

# 检查并生成 DATABASE_URL
# 规则：如果 DATABASE_URL 为空，或者 POSTGRES_PASSWORD 刚生成新密码，则重新生成 DATABASE_URL
DATABASE_URL=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d'=' -f2)
SHOULD_GENERATE_URL=false

if [ -z "$DATABASE_URL" ]; then
    SHOULD_GENERATE_URL=true
    echo "DATABASE_URL 为空，需要生成"
elif [ -n "$NEW_POSTGRES_PASSWORD" ]; then
    # POSTGRES_PASSWORD 刚生成了新密码，强制重新生成 DATABASE_URL
    SHOULD_GENERATE_URL=true
    echo "POSTGRES_PASSWORD 已更新，重新生成 DATABASE_URL"
fi

if [ "$SHOULD_GENERATE_URL" = true ]; then
    # 使用新生成或已存在的密码
    PASSWORD_TO_USE="${NEW_POSTGRES_PASSWORD:-$POSTGRES_PASSWORD}"
    NEW_DATABASE_URL=$(generate_database_url "$PASSWORD_TO_USE")
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=$NEW_DATABASE_URL|" "$ENV_FILE"
    echo "已生成 DATABASE_URL"
else
    echo "DATABASE_URL 已存在且密码未变更，跳过生成"
fi

echo "环境变量初始化完成"
