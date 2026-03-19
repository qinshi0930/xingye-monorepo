# 方案 B：直接使用 CI 预构建产物
# CI 验证后，构建产物位于 dist/ 目录，本 Dockerfile 仅负责打包运行
#
# 构建方式:
#   podman build --target web -t xingye-web .

FROM node:20-alpine AS web
WORKDIR /app/web
ENV NODE_ENV=production

# 复制 CI 预构建产物（构建产物位于 dist/web/ 目录）
COPY dist/web/.next/standalone ./
COPY dist/web/.next/static ./.next/static
COPY dist/web/public ./public

EXPOSE 3000
CMD ["node", "server.js"]

# ============================================
# 多应用支持占位 - Admin 管理后台
# ============================================
# FROM node:20-alpine AS admin
# WORKDIR /app/admin
# ENV NODE_ENV=production
# COPY dist/admin/.next/standalone ./
# COPY dist/admin/.next/static ./.next/static
# COPY dist/admin/public ./public
# EXPOSE 3000
# CMD ["node", "server.js"]

# ============================================
# 多应用支持占位 - API 服务
# ============================================
# FROM node:20-alpine AS api
# WORKDIR /app/api
# ENV NODE_ENV=production
# COPY dist/api/.next/standalone ./
# COPY dist/api/.next/static ./.next/static
# COPY dist/api/public ./public
# EXPOSE 3000
# CMD ["node", "server.js"]
