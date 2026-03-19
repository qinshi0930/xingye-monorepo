# Xingye Monorepo 部署架构文档

> **必读**: 本文档是部署系统的核心知识库，任何改动前请先阅读本文档并查阅 [DEPLOY_CHANGELOG.md](./DEPLOY_CHANGELOG.md) 了解历史变更。

---

## 1. 架构概览

### 1.1 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                        宿主机 (Host)                         │
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │   开发环境   │    │           生产环境 (/var/www/)       │ │
│  │   :3000     │    │  ┌─────────┐    ┌────────────────┐  │ │
│  │  (直接访问)  │    │  │  Nginx  │────│  Next.js App   │  │ │
│  └─────────────┘    │  │ :8080   │    │   :3000        │  │ │
│                     │  └─────────┘    └────────────────┘  │ │
│                     └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 关键文件位置

| 文件 | 作用 | 注意事项 |
|------|------|----------|
| `Dockerfile` | 生产镜像构建 | 使用 CI 预构建产物 |
| `podman-compose.yml` | 生产编排 | 包含 Nginx + App 服务 |
| `podman-compose.infra.yml` | 基础设施编排 | PostgreSQL + Redis |
| `podman-compose.ci.yml` | CI 验证环境 | 完整 CI 流程容器化 |
| `deploy.sh` | 自动化部署 | 复用 CI 产物，支持回滚 |
| `ci-validate.sh` | CI 验证脚本 | lint + type-check + test + build |
| `config/nginx/` | Nginx 配置 | 生产环境反向代理配置 |

---

## 2. 设计原则

### 2.1 Rootless 部署
- **不使用 sudo** 运行容器（已授予 `/var/www` 所有权给当前用户）
- **非特权端口**: 8080/8443 代替 80/443
- **用户命名空间**: 镜像构建和运行在同一命名空间

### 2.2 网络架构
- **自定义网络**: `app-network` (bridge)
- **DNS 解析**: 服务名作为主机名（`app` → Next.js 容器）
- **Nginx 代理**: `http://app:3000` 内部通信

### 2.3 配置管理
- **配置目录**: `config/nginx/` 存放所有 Nginx 配置
- **只读挂载**: `:ro` 标记确保配置不被容器修改
- **SSL 目录**: `config/nginx/ssl/` 用于证书（当前未启用）

---

## 3. 部署流程

### 3.1 标准部署命令

```bash
# 完整部署（CI验证 → 构建 → 部署 → 健康检查）
pnpm deploy:prod
# 或
./scripts/deploy.sh production

# 跳过 CI 验证（仅当已验证过时）
./scripts/deploy.sh production --skip-validate

# 仅重启生产环境
podman-compose -f /var/www/xingye-monorepo/podman-compose.yml restart

# 查看生产容器状态
podman-compose -f /var/www/xingye-monorepo/podman-compose.yml ps
```

### 3.2 部署步骤（deploy.sh）

1. **CI 验证** - 调用 `ci-validate.sh` (lint + type-check + test + build)
2. **检查构建产物** - 验证 `dist/.next/standalone` 存在
3. **构建生产镜像** - `podman build` (使用 CI 预构建产物)
4. **备份当前部署** - `tar czf`
5. **复制到部署路径** - `cp` (dist/, config/, .env 等)
6. **停止旧容器** - `podman-compose down`
7. **启动新容器** - `podman-compose up -d`
8. **健康检查** - PostgreSQL + Redis + HTTP
9. **清理临时资源**

### 3.3 CI 验证流程（ci-validate.sh）

CI 验证脚本负责构建并导出产物：

```bash
# 运行 CI 验证
pnpm validate
# 或
./scripts/ci-validate.sh

# 调试模式（保留容器）
./scripts/ci-validate.sh --skip-cleanup
```

**验证步骤：**
1. 启动 CI 容器（validator + postgres + redis）
2. 运行 lint 检查
3. 运行 type-check
4. 运行单元测试
5. 运行构建
6. 运行集成测试
7. 导出构建产物到 `dist/` 目录
8. 清理 CI 容器

**日志位置：** `logs/ci/validate-YYYYMMDD-HHMMSS.log`

### 3.4 日志记录

- **终端输出**: 简洁的步骤信息
- **部署日志**: `logs/deploy-YYYYMMDD-HHMMSS.log`
- **CI 验证日志**: `logs/ci/validate-YYYYMMDD-HHMMSS.log`
- **完整记录**: 所有命令的 stdout/stderr 都记录到日志
- **日志管理**: 自动保留最近 5 个日志文件

---

## 4. 故障排查

### 4.1 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 端口 80/443 绑定失败 | rootless 无法绑定特权端口 | 使用 8080/8443 |
| 镜像拉取失败 | 本地镜像被当作远程镜像 | 使用 `localhost/` 前缀或 `pull_policy: never` |
| 容器间无法通信 | 不在同一网络 | 检查 `networks` 配置 |
| Nginx 502 错误 | App 服务未启动 | 检查 `app` 容器健康状态 |

### 4.2 调试命令

```bash
# 查看容器日志
podman logs -f xingye-web
podman logs -f xingye-nginx
podman logs -f xingye-postgres
podman logs -f xingye-redis

# 进入容器排查
podman exec -it xingye-web sh
podman exec -it xingye-nginx sh

# 检查网络 DNS
podman exec xingye-nginx nslookup web

# 查看完整 compose 配置
podman-compose -f podman-compose.yml config

# 查看 CI 容器日志
podman logs xingye-ci-validator
podman logs xingye-ci-postgres
podman logs xingye-ci-redis
```

---

## 5. 修改指南

### 5.1 修改前检查清单

- [ ] 查阅 [DEPLOY_CHANGELOG.md](./DEPLOY_CHANGELOG.md) 了解相关历史变更
- [ ] 确认修改影响范围（开发/生产/两者）
- [ ] 检查是否需要同步更新 `deploy.sh`
- [ ] 检查是否需要同步更新 `config/nginx/`
- [ ] 测试部署脚本是否能正常执行

### 5.2 常见修改场景

**场景1: 修改 Nginx 配置**
```bash
# 1. 修改 config/nginx/conf.d/default.conf
# 2. 重启 Nginx 容器
podman-compose -f /var/www/xingye-monorepo/podman-compose.yml restart nginx
```

**场景2: 添加新服务到生产环境**
```bash
# 1. 修改 podman-compose.yml 添加服务
# 2. 更新 deploy.sh 中的复制逻辑（如需要）
# 3. 更新 config/ 目录结构（如需要）
# 4. 测试完整部署流程
```

**场景3: 修改部署脚本**
```bash
# 1. 修改 deploy.sh
# 2. 运行测试部署
# 3. 检查 logs/ 目录下的日志输出
```

---

## 6. 关键配置说明

### 6.1 podman-compose.yml 关键配置

```yaml
services:
  app:
    expose:           # 只在容器网络暴露，不映射到宿主机
      - "3000"
    networks:         # 必须指定同一网络
      - app-network
    
  nginx:
    ports:            # 映射到宿主机的非特权端口
      - "8080:80"
      - "8443:443"
    depends_on:       # 确保启动顺序
      - app
    networks:         # 同一网络才能通信
      - app-network
```

### 6.2 Nginx 反向代理配置

```nginx
upstream nextjs_app {
    server app:3000;  # 使用服务名，不是 container_name
}

location / {
    proxy_pass http://nextjs_app;
    # 必须设置这些 header
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

---

## 7. 参考文档

- [DEPLOY_CHANGELOG.md](./DEPLOY_CHANGELOG.md) - 完整变更历史（按时间倒序）
- [Dockerfile](../Dockerfile) - 镜像构建配置
- [deploy.sh](../deploy.sh) - 自动化部署脚本

---

**文档版本**: 3.0  
**最后更新**: 2026-03-19  
**维护说明**: 本文档只包含核心架构知识，具体改动请查阅 CHANGELOG

---

## 8. 架构演进

### 8.1 方案 B：CI 产物复用模式

当前部署架构采用"方案 B"设计：

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   CI 验证阶段    │────▶│   产物导出      │────▶│   部署阶段      │
│  ci-validate.sh │     │   dist/         │     │  deploy.sh      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                              │
        ▼                                              ▼
  - lint                                          检查产物
  - type-check                                    构建镜像
  - test                                          备份/部署
  - build                                         健康检查
  - integration
```

**优势：**
- 构建一次，部署多次
- 验证与部署职责分离
- 部署流程更快（跳过构建）
- 生产环境使用与验证环境一致的产物
