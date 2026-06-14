# Docker Compose Watch

> 代码改了自动同步到容器，不需要手动重建——Windows 上比 Bind Mount 快得多

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.10

## 💡 核心概念

### 是什么

Compose v2.22+ 的新特性 `develop.watch`，监听宿主机文件变更，自动同步到容器（sync 模式）或触发镜像重建（rebuild 模式）。

### 为什么重要

- Windows 上 Bind Mount 跨文件系统 IO 性能差——Watch 用 WSL2 内部文件系统做中转
- 传统开发流程"改代码 → 重建 → 重启"太慢——Watch sync 秒级同步
- PHP 文件同步后 FPM 自动重新加载，无需手动操作

### 核心原理

**两种模式：**

| 模式 | 触发条件 | 动作 | 适合 |
|------|---------|------|------|
| `sync` | 文件内容变更 | 同步变更文件到容器 | PHP 代码、模板、静态资源 |
| `rebuild` | 指定文件变更 | 重建镜像并替换容器 | Dockerfile、composer.json、依赖文件 |

**与 Bind Mount 的对比：**
- Bind Mount = 实时映射，Windows ↔ WSL2 跨文件系统 IO 差
- Watch = 按需同步 + 缓存，文件先存 WSL2 内部再同步，性能更好
- Watch 支持同步后执行自定义命令（如 `composer dump-autoload`）

## 🛠 实践

### 本项目中的应用

```yaml
# docker-compose.yml
services:
  php:
    develop:
      watch:
        - path: ./public/
          target: /var/www/html/public/
          action: sync               # PHP 文件 → 同步
        - path: ./composer.json
          target: /var/www/html/composer.json
          action: rebuild            # 依赖变了 → 重建
```

### 日常开发命令

```bash
docker compose up --watch            # 前台 + 文件监听
docker compose up -d --watch         # 后台
```

## ⚠️ 踩坑记录

### 坑：改了代码没反应

**现象：** 修改 PHP 文件后页面没变化

**原因：** OPcache 缓存了旧文件（开发环境 OPcache 校验频率低）

**解决：** 开发环境 `php.ini` 设置 `opcache.validate_timestamps=1` + `opcache.revalidate_freq=0`

## 🔗 关联

- [数据管理](docker-data-management.md) — Bind Mount vs Watch 的对比
- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
