# 项目开发指南

> 本文档为 AI 辅助开发提供项目上下文，确保代码生成符合项目架构和规范。

---

## 1. 项目概述

本项目是一个**全栈应用开发模板**，采用分层架构设计，目标是提供开箱即用的基础设施，让开发者专注于业务逻辑实现。

### 1.1 核心定位
- **模板性质**: 不是完整应用，而是可扩展的基础架构
- **技术选型**: 现代、稳定、生产验证的技术栈
- **架构原则**: 分层清晰、职责单一、易于扩展

### 1.2 已完成的基础设施
- ✅ 数据库层 (PostgreSQL + Drizzle ORM)
- ✅ 缓存层 (Redis + 完整封装 + 健康检查)
- ✅ 日志系统 (Pino + 结构化输出)
- ✅ 容器化部署 (Podman/Docker + 双环境)
- ✅ 自动化部署 (部署脚本 + 备份回滚)
- ✅ 测试框架 (Jest + React Testing Library)
- ✅ 代码规范 (ESLint + TypeScript Strict)

### 1.3 待实现的业务层
- ⬜ API Routes (Next.js Route Handlers)
- ⬜ 认证系统 (建议 NextAuth 或 Lucia)
- ⬜ 前端页面 (管理界面)
- ⬜ 业务逻辑 (根据具体需求)

---

## 2. 架构规范

### 2.1 目录结构规范

```
├── apps/                       # 应用目录 (Monorepo)
│   ├── web/                   # Web 主应用 (Next.js)
│   │   ├── app/              # Next.js App Router
│   │   ├── components/       # React 组件
│   │   ├── lib/              # 应用内工具
│   │   └── package.json      # 应用依赖
│   ├── admin/                # 管理后台 (预留)
│   └── api/                  # API 服务 (预留)
├── packages/                   # 共享包
│   ├── config-eslint/        # ESLint 共享配置
│   ├── config-typescript/    # TypeScript 共享配置
│   ├── logger/               # 日志模块 (Pino)
│   └── redis-core/           # Redis 缓存封装
├── scripts/                    # 部署脚本
│   ├── init-env.sh           # 初始化环境变量
│   ├── install.sh            # 项目安装脚本
│   ├── ci-validate.sh        # CI 验证脚本
│   ├── deploy.sh             # 生产部署脚本
│   └── build-apps.sh         # 多应用构建脚本
├── config/nginx/               # Nginx 配置
└── docs/                       # 项目文档
```

### 2.2 分层调用规则

```
┌─────────────────────────────────────┐
│  表现层 (app/)                       │
│  - API Routes                        │
│  - Server/Client Components          │
└──────────────┬──────────────────────┘
               │ 调用
┌──────────────▼──────────────────────┐
│  业务层 (services/ - 待创建)          │
│  - 业务逻辑封装                        │
│  - 事务管理                           │
└──────────────┬──────────────────────┘
               │ 调用
┌──────────────▼──────────────────────┐
│  数据层 (lib/db/, lib/redis/)        │
│  - CRUD 操作                         │
│  - 缓存操作                          │
└──────────────┬──────────────────────┘
               │ 调用
┌──────────────▼──────────────────────┐
│  基础设施 (数据库/缓存连接)            │
│  - PostgreSQL (Drizzle)              │
│  - Redis (ioredis)                   │
└─────────────────────────────────────┘
```

**重要规则**:
- 上层可以调用下层，禁止反向调用
- 同层之间可以相互调用
- 缓存层对业务层透明，已在 CRUD 中集成

---

## 3. 数据库规范

### 3.1 现有表结构

#### users 表
```typescript
{
  id: serial().primaryKey(),
  username: varchar(50).notNull().unique(),
  email: varchar(255).notNull().unique(),
  passwordHash: varchar(255).notNull(),
  displayName: varchar(100),
  avatarUrl: text,
  bio: text,
  isActive: boolean.default(true),
  isAdmin: boolean.default(false),
  createdAt: timestamp,
  updatedAt: timestamp,
}
```

#### posts 表
```typescript
{
  id: serial().primaryKey(),
  title: varchar(255).notNull(),
  slug: varchar(255).notNull().unique(),
  content: text.notNull(),
  excerpt: text,
  coverImage: text,
  authorId: integer.notNull().references(users.id),
  published: boolean.default(false),
  viewCount: integer.default(0),
  createdAt: timestamp,
  updatedAt: timestamp,
  publishedAt: timestamp,
}
```

#### categories 表
```typescript
{
  id: serial().primaryKey(),
  name: varchar(100).notNull().unique(),
  slug: varchar(100).notNull().unique(),
  description: text,
  createdAt: timestamp,
}
```

### 3.2 添加新表的规范

1. **在 schema.ts 中定义表**
2. **导出类型**: `export type NewXxx = typeof xxx.$inferInsert;`
3. **生成迁移**: `pnpm db:generate`
4. **执行迁移**: `pnpm db:migrate`
5. **添加 CRUD**: 在 crud.ts 中添加操作（可选缓存）
6. **添加测试**: 在 `__tests__/` 中添加测试

### 3.3 缓存集成规范

已集成的缓存操作：
- `getUserById` / `getUserByEmail` / `getUserByUsername`
- `getPostById` / `getPostBySlug`
- `getPublishedPosts` / `getPostsByAuthor`

添加新缓存的模板：
```typescript
import { getOrSet } from '@/lib/redis/cache';
import { CACHE_TTL, CACHE_PREFIX, buildCacheKey } from '@/lib/redis/config';

export async function getXxxById(id: number) {
  const cacheKey = buildCacheKey(CACHE_PREFIX.XXX, id);
  
  return getOrSet(
    cacheKey,
    async () => {
      // 数据库查询
      return result;
    },
    CACHE_TTL.XXX
  );
}
```

---

## 4. API 开发规范

### 4.1 Route Handlers 目录结构

建议的 API 目录结构：
```
app/api/
├── auth/
│   ├── login/route.ts
│   ├── register/route.ts
│   └── logout/route.ts
├── users/
│   ├── route.ts          # GET /api/users, POST /api/users
│   └── [id]/
│       └── route.ts      # GET /api/users/:id, PUT /api/users/:id, DELETE /api/users/:id
├── posts/
│   ├── route.ts
│   └── [id]/
│       └── route.ts
└── categories/
    ├── route.ts
    └── [id]/
        └── route.ts
```

### 4.2 Route Handler 模板

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createUser, getAllUsers } from '@/lib/db/crud';
import { NewUser } from '@/lib/db/schema';

// GET /api/users
export async function GET() {
  try {
    const users = await getAllUsers();
    return NextResponse.json({ success: true, data: users });
  } catch (error) {
    return NextResponse.json(
      { success: false, error: 'Failed to fetch users' },
      { status: 500 }
    );
  }
}

// POST /api/users
export async function POST(request: NextRequest) {
  try {
    const body: NewUser = await request.json();
    const user = await createUser(body);
    return NextResponse.json({ success: true, data: user }, { status: 201 });
  } catch (error) {
    return NextResponse.json(
      { success: false, error: 'Failed to create user' },
      { status: 500 }
    );
  }
}
```

### 4.3 响应格式规范

统一响应格式：
```typescript
// 成功响应
{
  success: true,
  data: T,
  meta?: { page, limit, total }  // 分页信息（可选）
}

// 错误响应
{
  success: false,
  error: string,
  code?: string  // 错误代码（可选）
}
```

---

## 5. 缓存使用指南

### 5.1 基础缓存操作

```typescript
import * as cache from '@/lib/redis/cache';

// 设置缓存
await cache.set('key', { data: 'value' }, 3600);

// 获取缓存
const data = await cache.get<{ data: string }>('key');

// 删除缓存
await cache.del('key');

// 批量删除
await cache.clear('pattern:*');
```

### 5.2 缓存装饰器

```typescript
import { withCache } from '@/lib/redis/cache-wrapper';

const getExpensiveData = withCache(
  async (id: number) => {
    // 耗时操作
    return result;
  },
  {
    key: (id) => `expensive:${id}`,
    ttl: 3600,
    condition: (result) => result !== null,
  }
);
```

### 5.3 缓存键规范

- 使用 `CACHE_PREFIX` 常量定义前缀
- 使用 `buildCacheKey()` 构建简单键
- 使用 `buildListCacheKey()` 构建列表键

```typescript
import { CACHE_PREFIX, buildCacheKey, buildListCacheKey } from '@/lib/redis/config';

// 单条数据
const userKey = buildCacheKey(CACHE_PREFIX.USER, userId);  // "user:id:123"

// 列表数据
const listKey = buildListCacheKey(CACHE_PREFIX.POSTS_LIST, {
  published: true,
  limit: 10,
  offset: 0,
});  // "posts:list:limit:10:offset:0:published:true"
```

---

## 6. 测试规范

### 6.1 测试文件位置
- 单元测试: `src/__tests__/*.test.ts`
- 组件测试: `src/components/**/*.test.tsx`

### 6.2 测试命名规范
```typescript
describe('Feature Name', () => {
  describe('Function Name', () => {
    it('应该...当...', async () => {
      // 测试代码
    });
  });
});
```

### 6.3 数据库测试
使用内存数据库或测试数据库，避免污染开发数据。

---

## 7. 开发工作流

### 7.1 添加新功能的标准流程

1. **定义数据模型** (schema.ts)
2. **生成并执行迁移** (db:generate, db:migrate)
3. **实现 CRUD 操作** (crud.ts，可选缓存)
4. **实现 API 路由** (app/api/)
5. **实现前端组件** (components/)
6. **编写测试** (__tests__/)
7. **验证并提交**

### 7.2 代码提交规范

提交信息格式：
```
<type>: <subject>

<body>
```

类型：
- `feat`: 新功能
- `fix`: 修复
- `docs`: 文档
- `refactor`: 重构
- `test`: 测试
- `chore`: 构建/工具

---

## 8. 环境配置

### 8.1 快速初始化（安装脚本）

项目提供了一键安装脚本，自动完成环境初始化：

```bash
# 使用默认项目名称 (my-app)
curl -fsSL https://raw.githubusercontent.com/qinshi0930/xingye-monorepo/main/scripts/install.sh | bash

# 指定项目名称
curl -fsSL https://raw.githubusercontent.com/qinshi0930/xingye-monorepo/main/scripts/install.sh | bash -s -- my-project

# 跳过依赖安装（适合 CI 环境）
curl -fsSL .../install.sh | bash -s -- my-project --skip-install

# 跳过 git 初始化
curl -fsSL .../install.sh | bash -s -- my-project --skip-git
```

**脚本功能：**
- 克隆模板仓库
- 自动重命名项目（package.json、容器名称）
- 生成随机安全密码（Redis、PostgreSQL）
- 初始化本地 git 仓库
- 安装项目依赖（pnpm 优先）

### 8.2 环境变量初始化

```bash
# 使用 init-env.sh 脚本初始化环境变量
./scripts/init-env.sh
```

脚本会自动：
- 检查 `.env` 文件是否存在
- 生成随机的 `REDIS_PASSWORD` 和 `POSTGRES_PASSWORD`
- 根据 PostgreSQL 配置自动生成 `DATABASE_URL`
- 密码更新时会自动重新生成 DATABASE_URL

### 8.3 环境变量

开发环境 (.env):
```bash
# 数据库
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb

# 或分散配置
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=user
POSTGRES_PASSWORD=pass
POSTGRES_DB=mydb

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

### 8.4 容器环境

开发环境使用 `podman-compose.infra.yml`，自动配置网络别名：
- `postgres` → PostgreSQL 容器
- `redis` → Redis 容器

**可用命令：**
```bash
pnpm infra:up     # 启动基础设施
pnpm infra:down   # 停止基础设施
pnpm infra:logs   # 查看日志
pnpm infra:reset  # 重置数据（谨慎使用）
```

---

## 9. 部署说明

### 9.1 生产部署

```bash
# 执行部署脚本（完整流程：CI验证 → 构建 → 部署）
pnpm deploy:prod

# 或使用脚本
./scripts/deploy.sh production

# 跳过 CI 验证（仅当已运行过验证时）
./scripts/deploy.sh production --skip-validate
```

部署脚本会：
1. 构建生产镜像（Dockerfile 多阶段构建）
2. 备份当前部署
3. 复制配置文件到部署目录（纯镜像模式不复制构建产物）
4. 启动新容器
5. 执行健康检查 (PostgreSQL + Redis + HTTP)
6. 失败自动回滚

> **纯镜像模式**: 部署时通过 Dockerfile 重新构建镜像，不再依赖 CI 预构建产物。这解决了 pnpm 软链接在容器中失效的问题。

### 9.2 部署特性

- **零停机部署**: 蓝绿部署模式
- **自动备份**: 每次部署自动备份旧版本
- **健康检查**: 多层级健康检查确保服务可用
- **自动回滚**: 部署失败自动恢复到上一版本
- **完整日志**: 所有操作记录到 `logs/` 目录

### 9.3 部署配置

- **生产编排**: `podman-compose.yml`
- **Nginx 配置**: `config/nginx/`
- **部署文档**: `docs/DEPLOY.md`
- **部署日志**: `logs/deploy-*.log`

---

## 10. 扩展建议

### 10.1 推荐添加的功能

按优先级排序：

1. **认证系统** (高优先级)
   - 建议: NextAuth.js 或 Lucia
   - 支持: 邮箱/密码、OAuth (GitHub/Google)

2. **API 路由** (高优先级)
   - RESTful API 实现
   - 请求验证 (Zod)
   - 错误处理中间件

3. **前端界面** (中优先级)
   - 管理后台布局
   - 数据表格组件
   - 表单组件

4. **文件存储** (中优先级)
   - 本地/云存储抽象
   - 图片上传/处理

5. **监控告警** (低优先级)
   - 应用性能监控 (APM)
   - 错误追踪 (Sentry)
   - 日志收集 (ELK/Fluentd)

### 10.2 技术选型建议

| 功能 | 推荐方案 | 理由 |
|------|----------|------|
| 认证 | Lucia | 轻量、现代、TypeScript 友好 |
| 表单 | React Hook Form + Zod | 性能优秀、验证强大 |
| 状态管理 | Zustand | 简单、高效 |
| 数据获取 | SWR/React Query | 缓存、重试、实时更新 |

---

## 附录

### A. 常用命令速查

```bash
# 项目初始化
curl -fsSL https://raw.githubusercontent.com/qinshi0930/xingye-monorepo/main/scripts/install.sh | bash

# 开发
pnpm dev:web                # 启动 web 开发服务器
pnpm dev:admin              # 启动 admin 开发服务器
pnpm dev:api                # 启动 api 开发服务器
pnpm dev:all                # 启动所有应用
pnpm build                  # 构建所有应用
pnpm lint                   # 运行 ESLint
pnpm type-check             # 运行 TypeScript 类型检查

# 数据库
pnpm db:generate            # 生成迁移
pnpm db:migrate             # 执行迁移
pnpm db:push                # 推送 schema
pnpm db:studio              # 数据库 GUI

# 测试
pnpm test                   # 运行所有测试
pnpm test:unit              # 仅运行单元测试
pnpm test:integration       # 仅运行集成测试

# CI/CD
pnpm validate               # 本地 CI 验证
pnpm ci:validate            # 容器环境 CI 验证
pnpm deploy:prod            # 生产部署

# 基础设施
pnpm infra:up               # 启动基础设施
pnpm infra:down             # 停止基础设施
pnpm infra:logs             # 查看基础设施日志
pnpm infra:reset            # 重置基础设施数据

# 脚本
./scripts/init-env.sh       # 初始化环境变量
./scripts/ci-validate.sh    # CI 验证
./scripts/deploy.sh         # 生产部署
./scripts/build-apps.sh     # 多应用构建
```

### B. 项目链接

- [Next.js 文档](https://nextjs.org/docs)
- [Drizzle ORM 文档](https://orm.drizzle.team/)
- [Tailwind CSS 文档](https://tailwindcss.com/docs)
- [shadcn/ui 文档](https://ui.shadcn.com/)
