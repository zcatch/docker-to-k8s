# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

PHP 开发者云原生学习项目。技术栈：PHP 8.2 (FPM) + Nginx (Alpine) + MySQL 8.0 + Redis 7，全部容器化运行。当前进度：阶段2 容器化全部完成，阶段3 自动化测试 待开始。

## 常用命令

```bash
# 开发环境
docker compose up --watch          # 前台 + 热重载
docker compose up -d --watch       # 后台
docker compose --profile debug up -d  # 带 Adminer (localhost:8081)

# 启停
docker compose stop / start / restart
docker compose down                # 删容器，保留数据
docker compose down -v             # 慎！数据全丢

# 日志
docker compose logs -f             # 全部
docker compose logs -f php         # 单服务

# 进入容器
docker exec -it myapp-php sh
docker exec -it myapp-mysql mysql -uroot -p
docker exec -it myapp-redis redis-cli -a $REDIS_PASSWORD

# 镜像
docker build -t myapp-php:latest .
docker system prune -f && docker builder prune -f
```

## 架构

**Compose 文件分层**：`docker-compose.yml`（骨架）→ 自动合并 `docker-compose.override.yml`（开发：端口映射）→ 手动指定 `docker-compose.prod.yml`（生产）

**Dockerfile 多阶段构建**：阶段1 `builder` 编译 PHP 扩展 + 装 Composer → 阶段2 `production` 只保留运行时，`USER www-data` 非 root 运行。最终镜像 ~130MB。

**服务间通信**：自定义 bridge 网络 `app-network`，容器通过服务名 DNS 互访（如 `fastcgi_pass php:9000`）。开发环境暴露端口 8080/3306/6379，生产环境数据库不应暴露。

**代码同步**：`develop.watch` 的 `sync` 模式，Windows 上比 bind mount IO 性能更好。

## 约定

- `.env` 不提交 Git，`.env.example` 做模板
- 所有服务配置健康检查 + 日志轮转（`json-file`，10M/3文件）
- Nginx `depends_on` PHP 的 `service_healthy`，保证启动顺序
- MySQL 数据用命名卷 `mysql-data` 持久化
- Adminer 用 `profiles: [debug]` 按需启动
- 镜像已推送 Docker Hub：`bluetears/myapp-php:1.0.0`

## 当前代码

`public/index.php` 目前只有 `phpinfo()`，业务代码待开发。阶段4 CI/CD 进行中。

## 学习系统

[`docs/学习路线.md`](./docs/学习路线.md) — 13 阶段导航 + 进度追踪，当前阶段4（CI/CD）进行中。

**工作流：** 路线选知识点 → 复制 [`docs/concepts/_template.md`](./docs/concepts/_template.md) 写笔记 → 踩坑记到笔记 ⚠️ 区 + 汇总到 [`docs/学习答疑.md`](./docs/学习答疑.md) → 回路线勾进度。详见 [`docs/concepts/README.md`](./docs/concepts/README.md)。
