# 方案 B：直接使用 CI 预构建产物
# CI 验证后，构建产物位于 dist/ 目录，本 Dockerfile 仅负责打包运行
#
# 构建方式:
#   podman build --target web -t xingye-web .

FROM node:20-alpine AS web
WORKDIR /app
ENV NODE_ENV=production

# 复制 CI 预构建产物（由 ci-validate.sh 导出到 dist/ 目录）
COPY dist/.next/standalone ./
COPY dist/.next/static ./.next/static
COPY dist/public ./public

EXPOSE 3000
CMD ["node", "server.js"]

# ============================================
# 多应用支持占位 - Admin 管理后台
# ============================================
# 注意: 需要先在 ci-validate.sh 中实现 admin 构建产物导出
# FROM node:20-alpine AS admin
# WORKDIR /app
# ENV NODE_ENV=production
# COPY dist/admin/.next/standalone ./
# COPY dist/admin/.next/static ./.next/static
# COPY dist/admin/public ./public
# EXPOSE 3000
# CMD ["node", "server.js"]

# ============================================
# 多应用支持占位 - API 服务
# ============================================
# 注意: 需要先在 ci-validate.sh 中实现 api 构建产物导出
# FROM node:20-alpine AS api
# WORKDIR /app
# ENV NODE_ENV=production
# COPY dist/api/.next/standalone ./
# COPY dist/api/.next/static ./.next/static
# COPY dist/api/public ./public
# EXPOSE 3000
# CMD ["node", "server.js"]
