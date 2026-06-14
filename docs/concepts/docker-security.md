# 镜像安全加固

> 非 root 运行 + 漏洞扫描 + .dockerignore，把攻击面降到最低

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.6

## 💡 核心概念

### 是什么

容器安全不是"加一层防护"，而是从构建阶段就遵循最小权限原则：不用 root 运行、不把密钥打进镜像、持续扫描已知漏洞。

### 为什么重要

- 容器被攻破后的权限取决于容器内用户——root 被破 = 整个容器沦陷
- 密钥打进镜像层后，任何人拿到镜像都能提取
- 已知 CVE 漏洞是攻击者最常用的入侵途径

### 核心原理

**最小权限原则（Principle of Least Privilege）：**
- 容器默认以 root 运行——如果应用被攻破，攻击者拥有容器内完整 root 权限
- `USER www-data` 切换到非特权用户，即使被攻破也无法修改系统文件
- PHP-FPM 官方镜像内置 `www-data` 用户（UID 82），在 Dockerfile 最后显式切换

**`.dockerignore` 的作用：**
- 类似 `.gitignore`，排除不发送到构建上下文的文件
- 减小构建上下文体积、加快构建、防止密钥泄露
- 常见排除：`.git`、`node_modules`、`vendor`、`.env`、`*.md`

**镜像漏洞扫描：**
- Docker Scout（官方）/ Trivy（Aqua Security，开源）扫描镜像中的已知 CVE
- 频繁更新基础镜像是减少漏洞的最有效手段

## 🛠 实践

### 本项目中的应用

```dockerfile
# Dockerfile 最后
USER www-data              # 切换到非 root
```

```ini
# php.ini
expose_php = Off           # 隐藏 PHP 版本头
```

```yaml
# docker-compose.yml
services:
  php:
    security_opt:
      - no-new-privileges:true   # 禁止提权
    read_only: true              # 只读文件系统（除必要目录外）
```

```bash
# 扫描镜像
docker scout quickview myapp-php:latest
```

## ⚠️ 踩坑记录

### 坑：切换 USER 后文件写不进去

**现象：** `fopen()` 报 permission denied

**原因：** 文件属主是 root，`www-data` 没有写权限

**解决：** Dockerfile 中 `COPY` 后 `RUN chown -R www-data:www-data /var/www/html`

## 🔗 关联

- [多阶段构建](docker-multi-stage.md) — Builder 阶段的编译工具不会进生产镜像
- 学习路线：[阶段6 安全专项](../学习路线.md#sec-new-6)
- 答疑：[相关条目](../学习答疑.md)
