# MyApp — PHP 云原生学习项目

> 从 Windows 开发到企业级云原生架构的完整实践
> 阶段2 容器化 ✅ → 阶段3 自动化测试 🎯

## 📋 概览

| | |
|---|---|
| 技术栈 | PHP 8.2 + Nginx (Alpine) + MySQL 8.0 + Redis 7 |
| 容器化 | Docker 多阶段构建 + Docker Compose |
| 环境 | Windows + Docker Desktop + WSL2 |
| 镜像 | `bluetears/myapp-php:1.0.0` |

## 🚀 快速开始

**前置要求：** Docker Desktop 已安装，至少 4GB 可用内存。

```bash
# 1. 复制环境变量
cp .env.example .env

# 2. 启动（带热重载）
docker compose up --watch

# 3. 访问 http://localhost:8080
```

可选：带数据库管理工具启动：

```bash
docker compose --profile debug up --watch
# Adminer → http://localhost:8081（服务器填 mysql，用户名 root）
```

## 📁 项目结构

```
myapp/
├── public/                        # Web 根目录
│   └── index.php                  # 入口文件
├── docker/
│   ├── nginx/default.conf         # Nginx 配置
│   └── php/
│       ├── php.ini                # PHP 配置（开发）
│       ├── php.ini.prod           # PHP 配置（生产）
│       └── www.conf               # PHP-FPM 进程池
├── Dockerfile                     # 多阶段构建（Alpine，~130MB）
├── docker-compose.yml             # 基础服务骨架
├── docker-compose.override.yml    # 开发环境覆盖（自动加载）
├── docker-compose.prod.yml        # 生产环境覆盖（-f 显式指定）
├── .env / .env.example            # 环境变量
├── docs/
│   ├── 学习路线.md                 # 13 阶段完整路线
│   └── 学习答疑.md                 # 学习问题记录
└── CLAUDE.md                      # Claude Code 项目上下文
```

## 🏗️ 架构要点

**多阶段构建** — builder 阶段编译扩展 + 安装 Composer，production 阶段只保留运行时。镜像从 950MB+ 降到 ~130MB。

**Compose 文件分层** — `docker-compose.yml`（骨架）→ `override`（开发：端口映射，自动合并）→ `prod`（生产，手动指定）。同一镜像，不同环境不同配置。

**非 root 运行** — PHP 容器以 `www-data` 用户运行，最小权限原则。

**健康检查 + 日志轮转** — 所有服务配置 healthcheck，依赖 `service_healthy` 保证启动顺序；日志 `json-file` 驱动，10MB × 3 文件轮转。

**热重载开发** — `compose watch` sync 模式，代码改动秒级同步到容器，Windows 上比 bind mount IO 性能更好。

## 🐳 常用命令

```bash
docker compose up --watch           # 启动（前台 + 热重载）
docker compose up -d --watch        # 启动（后台）
docker compose down                 # 停止并删除容器（保留数据）
docker compose logs -f php          # 查看 PHP 日志
docker exec -it myapp-php sh        # 进入 PHP 容器
docker exec -it myapp-mysql mysql -uroot -p   # 进入 MySQL
docker build -t myapp-php:latest .  # 手动构建镜像
docker system prune -f && docker builder prune -f  # 清理
```

> 更多命令见 [CLAUDE.md](./CLAUDE.md)

## 🌐 服务地址

| 服务 | 地址 | 备注 |
|---|---|---|
| Web | `http://localhost:8080` | 主应用 |
| Adminer | `http://localhost:8081` | 需 `--profile debug` |
| MySQL | `localhost:3306` | 可用 Navicat 等客户端直连 |
| Redis | `localhost:6379` | 可用 RedisInsight 等客户端直连 |

## 🔧 配置

### 环境变量

```env
MYSQL_ROOT_PASSWORD=change_me
MYSQL_DATABASE=myapp
REDIS_PASSWORD=change_me
MYSQL_PORT=3306
REDIS_PORT=6379
NGINX_PORT=8080
```

### Compose 文件

| 文件 | 用途 | 加载方式 |
|---|---|---|
| `docker-compose.yml` | 服务骨架 | 自动 |
| `docker-compose.override.yml` | 开发环境（端口映射等） | 自动合并 |
| `docker-compose.prod.yml` | 生产环境 | `docker compose -f ...` |

## 📚 文档

| 文档 | 说明 |
|---|---|
| [CLAUDE.md](./CLAUDE.md) | 项目上下文（命令、架构、约定）— Claude Code 使用 |
| [学习路线](./docs/学习路线.md) | 13 阶段 DevOps 学习路线，从 PHP 基础到云原生 |
| [学习答疑](./docs/学习答疑.md) | 学习过程中的问题与解答 |

## 🔒 安全

- 容器以非 root 用户运行（`www-data`）
- `.env` 不提交 Git，敏感信息不入镜像
- 生产环境不暴露数据库端口
- 镜像漏洞扫描（Docker Scout）
- 最小权限原则

## 🆘 常见问题

**端口被占用？** 修改 `docker-compose.override.yml` 端口映射：
```yaml
nginx:
  ports:
    - "8081:80"   # 改成其他端口
```

**容器启动失败？** 查看日志定位：
```bash
docker compose logs php
docker compose logs mysql
```

**清理数据卷（数据全丢！）：**
```bash
docker volume rm myapp_mysql-data
```

## 📄 许可证

本项目为学习项目，仅供学习使用。
