-- PostgreSQL 初始化脚本
-- 首次启动时自动执行

-- 创建应用数据库（如果不存在）
-- SELECT 'CREATE DATABASE master_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'master_db')\gexec

-- 授权
GRANT ALL PRIVILEGES ON DATABASE master_db TO xingye;

-- 创建扩展（可选）
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
