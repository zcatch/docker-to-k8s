# Dockerfile 单阶段构建

> 用一个 Dockerfile 把 PHP 应用和所有依赖打包成可运行的镜像

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.1

## 💡 核心概念

### 是什么

Dockerfile 是一个声明式脚本，告诉 Docker 如何从零构建一个镜像。单阶段构建指用一个 `FROM` 指令完成所有工作——装系统依赖、编译扩展、复制代码、设置启动命令。

### 为什么重要

没有 Dockerfile 就没有自定义镜像。理解每条指令的作用是容器化的基础。单阶段构建虽然不完美（镜像大、有编译残留），但它是最容易理解的起点。

### 核心原理

**基础指令：**

| 指令 | 作用 | 示例 |
|------|------|------|
| `FROM` | 指定基础镜像 | `FROM php:8.2-fpm-alpine` |
| `RUN` | 在构建时执行命令 | `RUN apk add --no-cache libpng-dev` |
| `COPY` | 从宿主机复制文件到镜像 | `COPY public/ /var/www/html/public/` |
| `CMD` | 容器启动时的默认命令 | `CMD ["php-fpm"]` |
| `WORKDIR` | 设置工作目录 | `WORKDIR /var/www/html` |
| `EXPOSE` | 声明容器监听的端口 | `EXPOSE 9000` |

**PHP 扩展安装三种方式：**
1. `docker-php-ext-install` — 安装 PHP 内置扩展（如 pdo_mysql, gd）
2. `pecl install` — 安装 PECL 扩展（如 redis, xdebug）
3. `docker-php-ext-enable` — 启用已安装的扩展

## 🛠 实践

### 本项目中的应用

```dockerfile
FROM php:8.2-fpm-alpine

# 安装系统依赖
RUN apk add --no-cache \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    libzip-dev icu-dev

# 安装 PHP 扩展
RUN docker-php-ext-install -j$(nproc) \
    pdo_mysql gd mbstring zip opcache

# 安装 Redis 扩展
RUN pecl install redis && docker-php-ext-enable redis

# 复制代码
COPY public/ /var/www/html/public/

# 复制配置
COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

WORKDIR /var/www/html
EXPOSE 9000
CMD ["php-fpm"]
```

## ⚠️ 踩坑记录

### 坑：Alpine 的 PECL 频道报错

**现象：** `pecl install redis` 报 `No releases available`

**原因：** Alpine 镜像的 PECL 没有初始化频道元数据

**解决：** 在 `pecl install` 前先跑 `pecl channel-update pecl.php.net`

### 坑：GD 扩展装不上

**现象：** `docker-php-ext-install gd` 报缺少依赖

**原因：** GD 需要 libpng、libjpeg、freetype 等系统库，必须先 `apk add` 安装

**解决：** 先装系统库 `apk add libpng-dev libjpeg-turbo-dev freetype-dev`，再装 GD 扩展

## 🔗 关联

- [多阶段构建](docker-multi-stage.md) — 单阶段的进化版
- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
