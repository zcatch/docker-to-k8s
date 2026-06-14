# Docker Compose 多环境配置

> 同一镜像 + 不同 Compose 文件 = 适配开发/生产环境，一次构建处处运行

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.3

## 💡 核心概念

### 是什么

Compose 文件分层：一个基础骨架 + 环境专属覆盖文件。开发环境自动加载 `docker-compose.override.yml`，生产环境手动指定 `docker-compose.prod.yml`。同一份镜像在不同环境用不同配置运行。

### 为什么重要

- **避免环境漂移**：不会出现"我本地能跑啊"的问题
- **安全隔离**：开发环境暴露端口方便调试，生产环境数据库不对外
- **配置复用**：公共配置写一次，环境差异只写覆盖部分

### 核心原理

**Dockerfile vs Compose 分工：**
- Dockerfile → **编译时**：怎么造镜像（装依赖、编译扩展）
- Compose → **运行时**：怎么跑镜像（端口、环境变量、卷、资源限制）
- 同一镜像 + 不同 Compose 文件 = 环境适配

**多文件合并规则：**
- `docker-compose.override.yml` 是默认开发覆盖文件名，`docker compose up` 自动合并
- 非标准命名（如 `docker-compose.dev.yml`）不会自动加载，必须 `-f` 显式指定
- 多个 `-f` 文件按顺序合并，**后加载的覆盖先加载的**
- 生产部署：`docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`

**`.env` 管理：**
- 集中存放密码、密钥等敏感信息，Compose 中用 `${变量名}` 引用
- `.env` 加入 `.gitignore` 和 `.dockerignore`，不提交
- `.env.example` 提交，给团队成员做模板

## 🛠 实践

### 本项目中的应用

```yaml
# docker-compose.yml（骨架 — 所有环境共享）
services:
  php:
    build: .
    image: myapp-php:latest
    networks:
      - app-network
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]

networks:
  app-network:
    driver: bridge

volumes:
  mysql-data:

# docker-compose.override.yml（开发 — 自动加载）
services:
  php:
    ports:
      - "8080:80"
  mysql:
    ports:
      - "3306:3306"

# docker-compose.prod.yml（生产 — 手动 -f 指定）
services:
  php:
    restart: always
  mysql:
    restart: always
    # 生产不暴露数据库端口！
```

## ⚠️ 踩坑记录

### 坑：override 文件改了配置但不生效

**现象：** 修改 `docker-compose.override.yml` 后 `docker compose up` 还是旧配置

**原因：** 容器已在运行，`up` 不会重建已有容器

**解决：** `docker compose up --force-recreate` 强制重建

## 🔗 关联

- [Compose 进阶特性](compose-advanced.md) — healthcheck, profiles, extends
- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
