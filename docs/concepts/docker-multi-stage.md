# Dockerfile 多阶段构建

> builder 编译 + production 运行，一个 Dockerfile 两个世界，镜像从 500MB 降到 130MB

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.2

## 💡 核心概念

### 是什么

一个 Dockerfile 中写多个 `FROM`，每个 `FROM` 开启独立的构建阶段。前一阶段（builder）负责编译安装，后一阶段（production）用 `COPY --from=builder` 只取最终产物。builder 中的所有编译工具和中间产物在最终镜像中全部丢弃。

### 为什么重要

- **镜像体积**：单阶段 ~500MB+ → 多阶段 ~130MB，节省存储和网络传输
- **安全性**：生产镜像不含编译工具（gcc、make）、dev 头文件，攻击面更小
- **分层清晰**：构建依赖和运行时依赖彻底分离

### 核心原理

**镜像分层机制：**
- 每条 `RUN` / `COPY` / `ADD` 指令生成一个只读层，所有层叠加形成最终镜像
- 层不可变——在后面的层中 `rm` 前面的文件，文件仍在磁盘上，只是被标记为"不可见"
- `docker history 镜像名` 查看所有层的大小和创建命令

**Alpine vs Debian：**
- Alpine 基础镜像 ~9MB（Debian ~100MB+），使用 musl libc 替代 glibc
- Alpine 用 `apk` 包管理器，`--no-cache` 不缓存索引，`--virtual .build-deps` 创建虚拟包组便于卸载
- **关键约束**：builder 和 production 必须用**同一基镜像**——musl 编译的 `.so` 不能给 glibc 用

## 🛠 实践

### 本项目中的应用

```dockerfile
# ============ 阶段 1: Builder ============
FROM php:8.2-fpm-alpine AS builder

RUN apk add --no-cache --virtual .build-deps \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    libzip-dev icu-dev $PHPIZE_DEPS

RUN docker-php-ext-install -j$(nproc) \
    pdo_mysql gd mbstring zip opcache

RUN pecl channel-update pecl.php.net \
    && pecl install redis \
    && docker-php-ext-enable redis

# ============ 阶段 2: Production ============
FROM php:8.2-fpm-alpine AS production

# 只装运行时库，不装 dev 包
RUN apk add --no-cache \
    libpng libjpeg-turbo freetype libzip icu

# 从 builder 复制编译好的扩展
COPY --from=builder /usr/local/lib/php/extensions/ \
    /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ \
    /usr/local/etc/php/conf.d/

COPY public/ /var/www/html/public/
COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

USER www-data
WORKDIR /var/www/html
EXPOSE 9000
CMD ["php-fpm"]
```

## ⚠️ 踩坑记录

### 坑：`<missing>` 在 docker history 中

**现象：** `docker history` 输出中出现 `<missing>` 行

**原因：** BuildKit 不持久化中间层 ID，这是优化行为，不是数据丢失

**解决：** 不用处理，正常现象。用 `docker history --no-trunc` 看完整命令

### 坑：builder 和 production 用了不同基础镜像

**现象：** 扩展加载报 `undefined symbol` 或直接段错误

**原因：** builder 用 Debian(glibc) 编译的 `.so` 无法在 Alpine(musl) 中加载

**解决：** 两个 `FROM` 必须用完全相同的基镜像

## 🔗 关联

- [单阶段构建](docker-single-stage.md) — 理解基础后再看多阶段
- [BuildKit 构建优化](buildkit-optimization.md) — 进一步优化构建速度
- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
