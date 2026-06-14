# ============================================================
# 阶段1：builder（Alpine — 编译阶段）
# ============================================================

# ── php:8.2-fpm-alpine：PHP 8.2 官方 Alpine 镜像（基础仅 ~30MB）──
FROM php:8.2-fpm-alpine AS builder

# ── 换阿里云镜像源（国内加速，Alpine 官方 CDN 常被墙）──
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# ── apk add：Alpine 的包管理器（对标 Debian 的 apt-get）──
# ── --no-cache：不缓存下载的包索引，用完即删（Alpine 专属，替代 apt-get 的 rm -rf /var/lib/apt/lists/*）──
# ── linux-headers：Linux 内核头文件，编译 C 扩展需要 ──
# ── $PHPIZE_DEPS：PHP 官方 Alpine 镜像内置环境变量 ──
# ──   展开后是 autoconf g++ gcc make 等编译工具链 ──
# ──   pecl install 依赖这些工具，装完扩展后丢弃 ──
# ── Alpine 的 -dev 包 = 开发头文件，对标 Debian 的 libxxx-dev ──
RUN apk upgrade --no-cache

RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        linux-headers \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libzip-dev \
        oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        gd \
        mbstring \
        zip \
        opcache \
        bcmath \
        exif \
    && pecl channel-update pecl.php.net && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# ── apk del .build-deps：装完扩展后立即卸载编译工具链 ──
# ──   --virtual .build-deps 创建了一个"虚拟包"组 ──
# ──   卸载时一条命令删除组内所有包，干净利落 ──

# ── Composer：和之前一样，只装在 builder ──
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/bin --filename=composer \
    && php -r "unlink('composer-setup.php');"


# ============================================================
# 阶段2：production（Alpine — 运行阶段）
# ============================================================

FROM php:8.2-fpm-alpine

# ── 只装运行时库（不带 -dev 后缀）──
# ── Alpine 运行时包名更简洁，直接去掉 -dev 就是运行时 ──
RUN apk upgrade --no-cache

RUN apk add --no-cache \
        libpng \
        libjpeg-turbo \
        freetype \
        libzip \
        oniguruma

# ── 从 builder 拷贝编译好的扩展（Alpine ↔ Alpine，二进制兼容）──
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# ── 配置文件 ──
COPY ./docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY ./docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

RUN mkdir -p /var/log/php && chown www-data:www-data /var/log/php && chmod 775 /var/log/php

WORKDIR /var/www/html

EXPOSE 9000

USER www-data
CMD ["php-fpm"]
