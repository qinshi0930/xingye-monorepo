# 多阶段构建 Dockerfile
# 使用 pnpm deploy 彻底解决软链接问题
# 构建方式: podman build --target web -t xingye-web .

# ============================================
# Stage 1: 基础镜像
# ============================================
FROM node:20-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# ============================================
# Stage 2: 构建阶段
# ============================================
FROM base AS build
COPY . /usr/src/app
WORKDIR /usr/src/app
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
RUN pnpm --filter web build
RUN pnpm deploy --filter=web --prod /prod/web

# ============================================
# Stage 3: Web 应用生产镜像
# ============================================
FROM base AS web
COPY --from=build /prod/web /prod/web
WORKDIR /prod/web
EXPOSE 3000
CMD ["pnpm", "start"]

# ============================================
# 多应用支持占位 - Admin 管理后台
# ============================================
# FROM base AS admin
# COPY --from=build /prod/admin /prod/admin
# WORKDIR /prod/admin
# EXPOSE 3000
# CMD ["pnpm", "start"]

# ============================================
# 多应用支持占位 - API 服务
# ============================================
# FROM base AS api
# COPY --from=build /prod/api /prod/api
# WORKDIR /prod/api
# EXPOSE 3000
# CMD ["pnpm", "start"]
