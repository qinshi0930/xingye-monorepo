# Xingye Monorepo

一个现代化、生产就绪的 Monorepo 全栈应用开发模板，基于 Next.js 16 + React 19 + TypeScript，采用 pnpm workspaces 管理多应用，集成 PostgreSQL 数据库和 Redis 缓存层。

> **模板定位**：这是一个**基础架构模板**，提供开箱即用的基础设施（数据库、缓存、CI/CD、容器化），开发者可基于此快速构建业务应用。
>
> - ✅ 完整的基础设施（DB、缓存、容器化、CI/CD）
> - ✅ 标准化的 Monorepo 结构
> - ⬜ 业务页面（需自行开发）
> - ⬜ 认证系统（建议集成 NextAuth/Lucia）
> - ⬜ admin/api 应用（预留占位，需自行实现）

## 技术栈

- **框架**: [Next.js 16](https://nextjs.org/) (App Router)
- **前端**: [React 19](https://react.dev/) + [TypeScript 5](https://www.typescriptlang.org/)
- **样式**: [Tailwind CSS 4](https://tailwindcss.com/) + [shadcn/ui](https://ui.shadcn.com/)
- **数据库**: [PostgreSQL](https://www.postgresql.org/) + [Drizzle ORM](https://orm.drizzle.team/)
- **缓存**: [Redis](https://redis.io/) + [ioredis](https://github.com/redis/ioredis)
- **容器化**: [Podman](https://podman.io/) / Docker
- **测试**: [Jest](https://jestjs.io/) + [React Testing Library](https://testing-library.com/)
- **包管理**: [pnpm](https://pnpm.io/)

## 项目结构

```
.
├── apps/
│   ├── web/              # Web 主应用 (Next.js)
│   ├── admin/            # 管理后台 (预留)
│   └── api/              # API 服务 (预留)
├── packages/
│   ├── config-eslint/    # ESLint 共享配置
│   ├── config-typescript/# TypeScript 共享配置
│   ├── logger/           # 日志模块 (Pino)
│   └── redis-core/       # Redis 缓存封装
├── config/nginx/         # Nginx 配置
├── scripts/              # 部署脚本
│   ├── init-env.sh       # 初始化环境变量
│   ├── install.sh        # 项目安装脚本
│   ├── ci-validate.sh    # CI 验证脚本
│   ├── deploy.sh         # 生产部署脚本
│   └── build-apps.sh     # 多应用构建脚本
├── docs/                 # 项目文档
├── Dockerfile            # 生产镜像
├── podman-compose.yml              # 生产环境编排
├── podman-compose.infra.yml        # 基础设施编排 (开发)
├── podman-compose.ci.yml           # CI 验证环境编排
└── pnpm-workspace.yaml   # pnpm 工作区配置
```

## 快速开始

### 使用此模板后的第一步

```bash
# 1. 初始化环境变量
./scripts/init-env.sh

# 2. 启动基础设施（PostgreSQL + Redis）
pnpm infra:up

# 3. 初始化数据库
pnpm db:generate
pnpm db:push

# 4. 启动开发服务器
pnpm dev:web

# 5. 访问 http://localhost:3000
```

---

### 详细步骤

#### 1. 环境准备

确保已安装：
- [Node.js 20+](https://nodejs.org/)
- [pnpm 10+](https://pnpm.io/installation)
- [Podman](https://podman.io/getting-started/installation) 或 Docker

#### 2. 初始化项目

#### 方式一：使用安装脚本（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/qinshi0930/xingye-monorepo/main/scripts/install.sh | bash

# 或指定项目名称
curl -fsSL https://raw.githubusercontent.com/qinshi0930/xingye-monorepo/main/scripts/install.sh | bash -s -- my-project
```

安装脚本会自动完成：克隆模板、重命名项目、生成环境变量、初始化 git、安装依赖。

#### 方式二：手动克隆

```bash
# 克隆项目
git clone https://github.com/qinshi0930/xingye-monorepo.git
cd xingye-monorepo

# 安装依赖
pnpm install

# 初始化环境变量
./scripts/init-env.sh
```

### 3. 启动开发环境

```bash
# 启动基础设施 (PostgreSQL + Redis)
pnpm infra:up

# 或手动启动
podman-compose -f podman-compose.infra.yml up -d

# 本地启动 Web 应用开发服务器
pnpm dev:web

# 或启动所有应用
pnpm dev:all
```

访问 http://localhost:3000 (web) | http://localhost:3001 (admin) | http://localhost:3002 (api)

### 4. 数据库迁移

```bash
# 生成迁移文件
pnpm db:generate

# 执行迁移
pnpm db:migrate

# 查看数据库 (可选)
pnpm db:studio
```

## 可用命令

```bash
# 开发
pnpm dev              # 启动 web 开发服务器
pnpm dev:web          # 启动 web 开发服务器
pnpm dev:admin        # 启动 admin 开发服务器
pnpm dev:api          # 启动 api 开发服务器
pnpm dev:all          # 启动所有应用
pnpm build            # 构建所有应用
pnpm lint             # 运行 ESLint
pnpm type-check       # 运行 TypeScript 类型检查

# 测试
pnpm test             # 运行所有测试
pnpm test:unit        # 运行单元测试
pnpm test:integration # 运行集成测试

# 数据库
pnpm db:generate      # 生成 Drizzle 迁移
pnpm db:migrate       # 执行数据库迁移
pnpm db:push          # 推送 schema 到数据库
pnpm db:studio        # 启动 Drizzle Studio

# 基础设施
pnpm infra:up         # 启动基础设施容器
pnpm infra:down       # 停止基础设施容器
pnpm infra:logs       # 查看基础设施日志
pnpm infra:reset      # 重置基础设施数据

# CI/CD
pnpm validate         # 运行 CI 验证 (lint + type-check + test + build)
pnpm ci:validate      # 在容器环境中运行完整 CI 验证
pnpm deploy:prod      # 执行生产部署
```

## 核心特性

### 数据库层
- **Drizzle ORM**: 类型安全的数据库操作
- **自动迁移**: 数据库 schema 版本管理
- **关系定义**: 用户-文章-分类关联模型
- **连接池管理**: 自动管理数据库连接生命周期

### 缓存层
- **Redis 封装**: 完整的缓存操作 API
- **Cache-Aside 策略**: 自动缓存回源
- **装饰器模式**: `withCache`、`Cacheable`、`CacheEvict`
- **分级 TTL**: 用户(1h) / 文章(30m) / 列表(5m)
- **自动失效**: 写操作自动清除相关缓存
- **健康检查**: Redis 连接状态监控

### 日志系统
- **Pino 日志**: 高性能结构化日志
- **分级输出**: 开发环境美化输出，生产环境 JSON
- **子日志器**: 支持按模块创建带上下文的日志

### 生产就绪
- **容器化部署**: Podman/Docker 完整支持（纯镜像多阶段构建）
- **双环境配置**: 开发/生产环境分离
- **Nginx 反向代理**: 静态资源服务 + 负载均衡
- **健康检查**: 容器自动重启机制
- **SSL 预留**: HTTPS 配置模板
- **自动化部署**: 纯镜像模式一键部署 with 备份回滚

## 文档

- [部署架构文档](./docs/DEPLOY.md) - 生产部署指南
- [部署变更日志](./docs/DEPLOY_CHANGELOG.md) - 部署配置变更历史
- [项目开发指南](./docs/GUIDE.md) - 项目开发规范与最佳实践

## 许可证

MIT
