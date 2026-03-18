# Next Fullstack Template 部署架构文档

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
| `Dockerfile` | 生产镜像构建 | 多阶段构建，使用官方源 |
| `podman-compose.yml` | 生产编排 | 包含 Nginx + App 服务 |
| `podman-compose.dev.yml` | 开发编排 | 仅 App 服务，端口 3000 |
| `deploy.sh` | 自动化部署 | rootless 部署，完整日志 |
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
# 完整部署（构建 → 测试 → 部署 → 健康检查）
./deploy.sh

# 仅重启生产环境
podman-compose -f /var/www/next-fullstack-template/podman-compose.yml restart

# 查看生产容器状态
podman-compose -f /var/www/next-fullstack-template/podman-compose.yml ps
```

### 3.2 部署步骤（deploy.sh）

1. **构建镜像** - `podman build`
2. **运行测试** - `pnpm test`
3. **导出构建产物** - `podman cp`
4. **备份当前部署** - `tar czf`
5. **复制到部署路径** - `cp`
6. **停止旧容器** - `podman-compose down`
7. **启动新容器** - `podman-compose up -d`
8. **健康检查** - `curl http://localhost:8080`
9. **清理临时文件**

### 3.3 日志记录

- **终端输出**: 简洁的步骤信息
- **日志文件**: `logs/deploy-YYYYMMDD-HHMMSS.log`
- **完整记录**: 所有命令的 stdout/stderr 都记录到日志

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
podman logs -f next-fullstack-template
podman logs -f next-fullstack-nginx

# 进入容器排查
podman exec -it next-fullstack-template sh
podman exec -it next-fullstack-nginx sh

# 检查网络 DNS
podman exec next-fullstack-nginx nslookup app

# 查看完整 compose 配置
podman-compose -f podman-compose.yml config
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
podman-compose -f /var/www/next-fullstack-template/podman-compose.yml restart nginx
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

**文档版本**: 2.0  
**最后更新**: 2026-03-15  
**维护说明**: 本文档只包含核心架构知识，具体改动请查阅 CHANGELOG
