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
# Stage 2: CI 验证阶段
# 用于封闭环境 CI 测试，与部署流程保持一致
# ============================================
FROM base AS ci
COPY . /usr/src/app
WORKDIR /usr/src/app
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
# 运行 CI 验证步骤（每个步骤独立 RUN，便于缓存和调试）
RUN pnpm lint
RUN pnpm type-check
RUN pnpm test:unit
RUN pnpm build
# 注意：集成测试需要数据库和 Redis，在 compose 中运行

# ============================================
# Stage 3: 构建阶段（生产）
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
