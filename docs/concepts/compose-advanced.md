# Docker Compose 进阶特性

> healthcheck 保证启动顺序、profiles 按需启动服务、资源限制防止容器抢占

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.8

## 💡 核心概念

### 是什么

Compose 除了编排容器外还提供生产级特性：健康检查（healthcheck）、按需启动（profiles）、配置继承（extends）、资源限制（mem_limit / cpus）和自动覆盖（override）。

### 为什么重要

- **healthcheck**：`depends_on` 只等容器启动不等服务就绪，healthcheck 填补这个缺口
- **profiles**：调试工具（Adminer）不需要一直跑，用 profiles 按需启动
- **资源限制**：防止一个容器耗尽宿主机资源影响其他服务

### 核心原理

**healthcheck 三种状态：**
```
starting → healthy（服务就绪，后续依赖可以启动）
starting → unhealthy（超过重试次数，标记不健康）
```
- MySQL：`mysqladmin ping -h localhost`
- Redis：`redis-cli ping`
- Nginx：`curl -f http://localhost/`

**profiles 按需启动：**
- Compose v3.9+ 支持，服务标记 `profiles: ["debug"]`
- 普通 `docker compose up` **不会**启动 profile 服务
- 需要 `docker compose --profile debug up` 才启动

**资源限制：**
- `mem_limit: 512m` — 硬限制，超过会被 OOM Kill
- `cpus: "1.0"` — 最多使用 1 个 CPU 核心

## 🛠 实践

### 本项目中的应用

```yaml
# docker-compose.yml
services:
  mysql:
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  redis:
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  php:
    depends_on:
      mysql:
        condition: service_healthy    # 等 MySQL 真正就绪
      redis:
        condition: service_healthy    # 等 Redis 真正就绪

  adminer:
    image: adminer:latest
    profiles: ["debug"]              # 只有 --profile debug 才启动
```

## ⚠️ 踩坑记录

### 坑：`depends_on` 不等服务就绪

**现象：** PHP 启动后连 MySQL 报 `connection refused`

**原因：** 没用 `condition: service_healthy`，depends_on 只等容器启动不等服务就绪

**解决：** 加上健康检查 + `condition: service_healthy`

## 🔗 关联

- [多环境配置](docker-compose-environments.md) — override 自动加载
- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
