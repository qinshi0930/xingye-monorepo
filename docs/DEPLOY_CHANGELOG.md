# 部署系统变更记录

> 按时间倒序记录所有部署相关的变更，新记录添加到顶部。

---

## 2026-03-15 - Nginx 配置目录迁移 + 日志增强

### 变更内容
- **配置目录重构**: `nginx/` → `config/nginx/`
- **日志系统增强**: `deploy.sh` 记录完整命令输出

### 影响文件
- `podman-compose.yml` - 更新 volumes 路径
- `deploy.sh` - 更新复制逻辑，新增 `run_cmd` 函数
- `docs/DEPLOY.md` - 重构为架构文档

### 技术细节
```bash
# 目录结构变更
nginx/
├── nginx.conf
├── conf.d/default.conf
└── ssl/

# 变为
config/
└── nginx/
    ├── nginx.conf
    ├── conf.d/default.conf
    └── ssl/
```

### 验证方式
```bash
# 检查新目录结构
ls -la config/nginx/

# 测试部署脚本日志
./deploy.sh
cat logs/deploy-*.log
```

---

## 2026-03-15 - Nginx 反向代理 + Rootless 部署

### 变更内容
- **添加 Nginx 服务**: 生产环境使用 Nginx 反向代理
- **实现完全 rootless**: 移除所有 sudo 调用
- **目录权限调整**: `/var/www` 归属当前用户

### 影响文件
- `podman-compose.yml` - 添加 nginx 服务，使用非特权端口
- `deploy.sh` - 移除 sudo，使用普通用户权限
- 新增 `config/nginx/` 目录及配置文件

### 技术细节
```yaml
# 端口变更: 80/443 → 8080/8443 (rootless 要求)
ports:
  - "8080:80"
  - "8443:443"
```

### 验证方式
```bash
# 访问生产环境
curl http://localhost:8080

# 检查容器状态（无 root 权限）
podman ps
```

---

## 2026-03-15 - 部署日志增强

### 变更内容
- **完整日志记录**: 所有命令的 stdout/stderr 写入日志文件
- **结构化输出**: 标记命令开始/结束/退出码

### 影响文件
- `deploy.sh` - 新增 `run_cmd()` 函数

### 技术细节
```bash
# 日志格式
[2026-03-15 17:30:00] 执行: 构建镜像
[2026-03-15 17:30:00] 命令: podman build ...
--- 命令输出开始 ---
[完整输出...]
--- 命令输出结束 (成功) ---
```

---

## 2026-03-15 - 自动化部署脚本

### 变更内容
- **创建 deploy.sh**: 完整的自动化部署流程
- **备份回滚机制**: 失败时自动回滚到上一版本
- **健康检查**: 部署后自动验证服务可用性

### 影响文件
- 新增 `deploy.sh`
- 新增 `logs/` 目录

### 功能特性
1. 镜像构建
2. 运行测试
3. 导出构建产物
4. 备份当前部署
5. 复制到部署路径
6. 停止旧容器
7. 启动新容器
8. 健康检查
9. 清理临时文件

### 使用方式
```bash
chmod +x deploy.sh
./deploy.sh
```

---

## 2026-03-14 - 开发环境配置

### 变更内容
- **创建 podman-compose.dev.yml**: 开发环境快速启动
- **简化开发流程**: 无需构建，直接运行

### 影响文件
- 新增 `podman-compose.dev.yml`

### 配置特点
```yaml
# 开发环境直接使用官方镜像
image: node:20-alpine
# 挂载源代码，实时生效
volumes:
  - .:/app
```

### 使用方式
```bash
podman-compose -f podman-compose.dev.yml up -d
```

---

## 2026-03-14 - 镜像源标准化

### 变更内容
- **移除国内镜像源**: 统一使用官方 npm/pnpm 源
- **删除 Dockerfile.dev**: 简化配置

### 影响文件
- `Dockerfile` - 使用官方 npm 安装 pnpm
- `podman-compose.dev.yml` - 使用官方 npm 安装 pnpm
- 删除 `Dockerfile.dev`

### 决策原因
- 开发环境使用官方源更稳定
- 避免镜像源配置不一致问题
- 简化维护成本

---

## 2026-03-14 - 初始部署架构

### 变更内容
- **创建 Dockerfile**: 多阶段构建生产镜像
- **创建 podman-compose.yml**: 生产环境编排
- **创建 DEPLOY.md**: 部署文档

### 架构特点
- 多阶段构建（builder + runner）
- 使用 node:20-alpine 基础镜像
- 静态导出（Next.js static export）

### 初始目录结构
```
next-fullstack-template/
├── Dockerfile
├── podman-compose.yml
├── podman-compose.dev.yml
└── docs/
    └── DEPLOY.md
```

---

## 变更记录规范

### 记录格式
```markdown
## YYYY-MM-DD - 变更标题

### 变更内容
- 简要描述变更点

### 影响文件
- 列出变更的文件

### 技术细节
- 关键配置/代码变更

### 验证方式
- 如何验证变更是否生效
```

### 何时记录
- [ ] 新增/删除服务
- [ ] 修改部署流程
- [ ] 变更端口/网络配置
- [ ] 修改脚本逻辑
- [ ] 重构目录结构
- [ ] 变更权限/安全设置

---

**维护说明**: 新变更添加到文档顶部，保持倒序排列
