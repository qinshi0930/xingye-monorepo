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
if [ -z "$POSTGRES_PASSWORD" ]; then
    NEW_POSTGRES_PASSWORD=$(generate_password)
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$NEW_POSTGRES_PASSWORD/" "$ENV_FILE"
    echo "已生成 POSTGRES_PASSWORD"
else
    echo "POSTGRES_PASSWORD 已存在，跳过生成"
fi

echo "环境变量初始化完成"
