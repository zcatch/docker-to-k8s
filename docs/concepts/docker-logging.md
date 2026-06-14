# Docker 日志管理

> 日志输出到 stdout/stderr，Docker 统一收集、轮转，撑不爆磁盘

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.7

## 💡 核心概念

### 是什么

Docker 捕获容器的 stdout/stderr，按配置的日志驱动（driver）写到宿主机。同时支持日志轮转（rotation）防止磁盘撑爆。

### 为什么重要

- 不加限制的话日志会无限增长，撑爆磁盘
- 集中式日志平台（阶段10 的 EFK）依赖 stdout/stderr 输出
- 容器重建后写文件的日志会丢——stdout/stderr 才是 12-Factor 推荐方式

### 核心原理

**日志驱动（Logging Driver）：**

| 驱动 | 输出位置 | 适用 |
|------|---------|------|
| `json-file`（默认） | 宿主机 JSON 文件 | 开发 + 小规模生产 |
| `syslog` | 系统 syslog | 传统运维 |
| `fluentd` | Fluentd 收集器 | EFK 栈 |
| `journald` | systemd journal | systemd 环境 |

**日志轮转（Log Rotation）：**
- `max-size: "10m"` — 单文件超过 10MB 就轮转
- `max-file: "3"` — 最多保留 3 个轮转文件

**stdout/stderr vs 文件日志：**
- 12-Factor App 原则：应用日志写 stdout/stderr，由运行时统一管理
- 写文件的问题：容器重建丢失、需要额外挂载卷、日志轮转复杂
- `docker logs 容器名` 查看 stdout/stderr 输出

## 🛠 实践

### 本项目中的应用

```yaml
# docker-compose.yml — 所有服务统一日志配置
services:
  php:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
  nginx:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
  mysql:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

### 常用命令

```bash
docker compose logs -f              # 所有服务
docker compose logs -f php          # 单服务
docker compose logs --tail=100 php  # 最近 100 行
docker compose logs --since=10m     # 最近 10 分钟
```

## ⚠️ 踩坑记录

### 坑：`docker logs` 只能看到 stdout/stderr

**现象：** 应用写日志到文件，`docker logs` 看不到

**原因：** Docker 只捕获 stdout/stderr，不管容器内的日志文件

**解决：** PHP 应用 `error_log` 指向 `/dev/stderr`，Nginx access/error log 指向 `/dev/stdout` 和 `/dev/stderr`

## 🔗 关联

- 学习路线：[阶段2](../学习路线.md#sec-8)
- 阶段10 可观测性：[学习路线](../学习路线.md#sec-55)
- 答疑：[相关条目](../学习答疑.md)
