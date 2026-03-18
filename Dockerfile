# 构建阶段
FROM node:20-alpine AS builder
WORKDIR /app
# 安装 pnpm
RUN npm install -g pnpm
# 复制依赖文件
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# 安装依赖
RUN pnpm install --frozen-lockfile
# 复制源代码
COPY . .
# 运行单元测试（使用 Mock，无需外部服务，跳过 Redis 集成测试）
RUN pnpm test:unit
# 构建应用
RUN pnpm build

# 生产阶段
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
# 复制 standalone 输出（已包含 node_modules 和 server.js）
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
# 暴露端口
EXPOSE 3000
# 启动应用（使用 standalone server.js）
CMD ["node", "server.js"]
