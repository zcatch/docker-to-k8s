# BuildKit 与构建优化

> 并行构建 + 缓存挂载 + 构建密钥 + 多平台镜像，让构建快且安全

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.9

## 💡 核心概念

### 是什么

BuildKit 是 Docker 18.09+ 引入的下一代构建引擎（Docker Desktop 默认启用）。核心升级：并行构建独立阶段、更智能的缓存、构建时安全注入密钥、多平台镜像支持。

### 为什么重要

- **速度**：并行构建不依赖的阶段，比传统顺序执行快很多
- **缓存**：`--mount=type=cache` 让 Composer 依赖跨构建保留，不用每次下载
- **安全**：`--mount=type=secret` 注入密钥不留在镜像层
- **跨平台**：一次构建生成 amd64 + arm64 多架构镜像

### 核心原理

**BuildKit vs 传统构建：**
- 传统：顺序执行每条指令，即使两条指令不相关
- BuildKit：自动分析依赖关系，独立阶段并行处理

**`--mount=type=cache`（缓存挂载）：**
```dockerfile
RUN --mount=type=cache,target=/root/.composer composer install
```
- Composer 依赖缓存跨构建保留，不用每次从头下载
- 缓存目录存在宿主机，构建完成后不随容器删除

**`--mount=type=secret`（构建密钥）：**
```bash
docker build --secret id=composer_auth,src=$HOME/.composer/auth.json .
```
- 构建时注入密钥，不进入最终镜像层
- 比 `COPY` + `RUN` + `rm` 安全（COPY 在中间层留下密钥）

**`docker buildx`（多平台构建）：**
- `docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .`
- 开发用 Mac M 系列（arm64），部署用 Linux 服务器（amd64）

## 🛠 实践

### 本项目中的应用

```dockerfile
# Dockerfile 中用缓存挂载加速 Composer 安装
RUN --mount=type=cache,target=/root/.composer \
    composer install --no-dev --optimize-autoloader
```

```bash
# 开启 BuildKit（Docker Desktop 已默认开启）
export DOCKER_BUILDKIT=1

# 多平台构建
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t bluetears/myapp-php:latest .
```

## ⚠️ 踩坑记录

### 坑：环境变量 `DOCKER_BUILDKIT=1` 不生效

**现象：** 构建还是用老引擎

**原因：** Docker Desktop 的 BuildKit 是全局开关，不是环境变量控制的

**解决：** Docker Desktop → Settings → Docker Engine → `"buildkit": true`

## 🔗 关联

- [多阶段构建](docker-multi-stage.md) — BuildKit 是多阶段构建的最佳搭档
- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
