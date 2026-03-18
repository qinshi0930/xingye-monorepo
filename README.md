# Next.js 全栈开发模板

一个现代化、生产就绪的全栈应用开发模板，基于 Next.js 16 + React 19 + TypeScript，集成 PostgreSQL 数据库和 Redis 缓存层。

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
├── src/
│   ├── app/              # Next.js App Router
│   ├── components/       # React 组件
│   │   └── ui/          # shadcn/ui 组件
│   ├── lib/
│   │   ├── db/          # 数据库层 (Drizzle ORM)
│   │   │   ├── schema.ts    # 数据库表定义
│   │   │   ├── crud.ts      # CRUD 操作 (带缓存)
│   │   │   └── index.ts     # 数据库连接
│   │   ├── redis/       # 缓存层 (Redis 封装)
│   │   │   ├── index.ts         # Redis 客户端
│   │   │   ├── cache.ts         # 缓存操作
│   │   │   ├── cache-wrapper.ts # 缓存装饰器
│   │   │   ├── config.ts        # 缓存配置
│   │   │   └── health.ts        # 健康检查
│   │   ├── logger/      # 日志模块 (Pino)
│   │   │   └── index.ts     # 日志配置
│   │   └── utils.ts     # 工具函数
│   └── __tests__/       # 测试文件
│       ├── unit/        # 单元测试
│       └── integration/ # 集成测试
├── config/nginx/        # Nginx 配置
├── drizzle/             # 数据库迁移文件
├── scripts/             # 部署脚本
├── docs/                # 项目文档
├── Dockerfile           # 生产镜像
├── podman-compose.yml   # 生产环境编排
└── podman-compose.dev.yml # 开发环境编排
```

## 快速开始

### 1. 环境准备

确保已安装：
- [Node.js 20+](https://nodejs.org/)
- [pnpm](https://pnpm.io/installation)
- [Podman](https://podman.io/getting-started/installation) 或 Docker

### 2. 初始化项目

#### 方式一：使用安装脚本（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/qinshi0930/next-fullstack-template/main/scripts/install.sh | bash

# 或指定项目名称
curl -fsSL https://raw.githubusercontent.com/qinshi0930/next-fullstack-template/main/scripts/install.sh | bash -s -- my-project
```

安装脚本会自动完成：克隆模板、重命名项目、生成环境变量、初始化 git、安装依赖。

#### 方式二：手动克隆

```bash
# 克隆项目
git clone <repository-url>
cd next-fullstack-template

# 安装依赖
pnpm install

# 初始化环境变量
pnpm init:env
```

### 3. 启动开发环境

```bash
# 启动所有服务 (App + PostgreSQL + Redis)
podman-compose -f podman-compose.dev.yml up -d

# 或仅启动数据库服务
podman-compose -f podman-compose.dev.yml up -d redis postgres

# 本地启动 Next.js 开发服务器
pnpm dev
```

访问 http://localhost:3000

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
pnpm dev              # 启动开发服务器
pnpm build            # 构建生产版本
pnpm start            # 启动生产服务器
pnpm lint             # 运行 ESLint

# 测试
pnpm test             # 运行所有测试
pnpm test:watch       # 监听模式运行测试
pnpm test:coverage    # 生成测试覆盖率报告

# 数据库
pnpm db:generate      # 生成 Drizzle 迁移
pnpm db:migrate       # 执行数据库迁移
pnpm db:push          # 推送 schema 到数据库
pnpm db:studio        # 启动 Drizzle Studio

# 部署
./scripts/deploy.sh   # 执行生产部署
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
- **容器化部署**: Podman/Docker 完整支持
- **双环境配置**: 开发/生产环境分离
- **Nginx 反向代理**: 静态资源服务 + 负载均衡
- **健康检查**: 容器自动重启机制
- **SSL 预留**: HTTPS 配置模板
- **自动化部署**: 一键部署脚本 with 备份回滚

## 文档

- [部署架构文档](./docs/DEPLOY.md) - 生产部署指南
- [部署变更日志](./docs/DEPLOY_CHANGELOG.md) - 部署配置变更历史
- [项目开发指南](./docs/GUIDE.md) - 项目开发规范与最佳实践

## 许可证

MIT
