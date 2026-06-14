# Docker 网络深入

> 自定义 bridge 网络让容器之间用服务名互相访问，生产环境数据库不对外暴露端口

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.4

## 💡 核心概念

### 是什么

Docker 网络让容器之间、容器与外部之间通信。常用三种模式：bridge（桥接，默认）、host（共用宿主机网络栈）、none（完全隔离）。

### 为什么重要

- **服务发现**：Compose 自动把服务名注册为 DNS，`php` 直接解析到 PHP 容器的 IP
- **安全隔离**：生产数据库不映射端口到宿主机，只有内网能访问
- **性能理解**：理解网络模式才能调试"连不上"的问题

### 核心原理

**三种网络模式对比：**

| 模式 | DNS 解析 | 外网访问 | 适用 |
|------|:---:|:---:|------|
| 自定义 bridge | ✅ 服务名互访 | 需 `ports` | **生产推荐** |
| 默认 bridge | ❌ 只能 IP | 需 `ports` | 基本不用 |
| host | ✅ | 直接暴露 | 极少数高性能场景 |

**自定义 bridge 的三个核心能力：**
1. **内置 DNS**：Compose 自动注册服务名，`php` 直接解析为容器 IP
2. **全端口互通**：同网络内的容器互相可访问所有端口，不需要 `ports` 映射
3. **内外隔离**：未加入此网络的容器无法访问内部服务

**端口映射 `8080:80`：**
- 左侧 = 宿主机端口（对外暴露），右侧 = 容器端口（内网监听）
- 没有此映射时容器端口仅内网可见
- 生产环境数据库/缓存**不应**暴露端口到宿主机

**子网与网关：**
- `172.19.0.0/16`：`/16` = 前 16 位是网段号，后 16 位可分配给容器（最多 65534 个 IP）
- `172.19.0.1`：网关 IP，容器所有出网流量经过此地址

## 🛠 实践

### 本项目中的应用

```yaml
# docker-compose.yml
networks:
  app-network:
    driver: bridge      # 自定义 bridge 网络

services:
  php:
    networks:
      - app-network     # PHP 加入此网络
    # 没有 ports —— PHP 不需要对外暴露 9000，Nginx 通过内网访问
  nginx:
    networks:
      - app-network
    ports:
      - "8080:80"       # 只暴露 Nginx
  mysql:
    networks:
      - app-network
    # 生产不暴露 3306！开发环境在 override 中暴露
```

**nginx 配置中直接用服务名：**
```nginx
fastcgi_pass php:9000;  # "php" 是 Compose 服务名，自动 DNS 解析
```

### 验证网络连通性

```bash
docker exec -it myapp-nginx sh
ping php               # 能用服务名 ping 通
nc -zv php 9000        # 检查 9000 端口是否通
```

## ⚠️ 踩坑记录

### 坑：Nginx 报 `host not found in upstream "php"`

**现象：** Nginx 启动报错，日志显示无法解析 upstream `php`

**原因：** Nginx 先于 PHP 启动，`depends_on` 没配置 `service_healthy` 条件

**解决：** 加 `depends_on: php: condition: service_healthy`

## 🔗 关联

- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
