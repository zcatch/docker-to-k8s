# Registry 与镜像分发

> 镜像的"GitHub"——存储、版本管理、分发 Docker 镜像。Docker Hub 是公共仓库，Harbor 是企业级私有仓库

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.11

## 💡 核心概念

### 是什么

Registry（镜像仓库）是 Docker 镜像的存储和分发中心。Docker Hub 是默认公共仓库（类似 GitHub），Harbor 是最流行的企业级私有仓库。

### 为什么重要

- 没有 Registry 镜像只在本地，团队协作和服务器部署无从谈起
- 标签策略决定了能不能精准定位版本——生产环境绝不能用 `latest`
- 私有仓库是企业的镜像"私服"，安全可控

### 核心原理

**镜像标签策略：**

| 标签 | 含义 | 何时用 |
|------|------|--------|
| `1.2.3` | 精确版本 | **生产部署**，可回滚 |
| `1.2` | 次版本锁定 | 预发布环境 |
| `1` | 主版本 | CI 通知 |
| `latest` | 最新构建 | **绝不能用于生产** |

**推荐 CI 策略：** 一次构建打三个标签 `1.2.3`、`1.2`、`latest`

**推送与拉取流程：**

```bash
# 1. 给本地镜像打仓库标签
docker tag myapp:latest bluetears/myapp:1.0.0

# 2. 推送
docker push bluetears/myapp:1.0.0

# 3. 任一机器拉取
docker pull bluetears/myapp:1.0.0
```

**命名规范：** `registry/namespace/repository:tag`
- `bluetears/myapp-php:1.0.0` → Docker Hub namespace 下的 myapp-php 仓库，1.0.0 版本

## 🛠 实践

### 本项目中的应用

```bash
# 构建并打标签
docker build -t bluetears/myapp-php:1.0.0 .

# 推送
docker login
docker push bluetears/myapp-php:1.0.0

# 验证
docker pull bluetears/myapp-php:1.0.0
```

### 标签管理

```bash
# 一个镜像多个标签
docker tag bluetears/myapp-php:1.0.0 bluetears/myapp-php:1.0
docker tag bluetears/myapp-php:1.0.0 bluetears/myapp-php:latest

# 查看远程仓库标签
docker image ls bluetears/myapp-php
```

## ⚠️ 踩坑记录

### 坑：push 报 `denied: requested access to the resource is denied`

**现象：** `docker push` 报权限拒绝

**原因：** 没登录 Docker Hub，或者仓库名不对（namespace 不存在）

**解决：** `docker login` 后确认仓库名格式 `你的用户名/镜像名:标签`

## 🔗 关联

- 学习路线：[阶段4 CI/CD](../学习路线.md#sec-36) — 自动化构建推送
- 学习路线：[阶段5 Harbor](../学习路线.md#sec-44) — 企业级私有仓库
- 答疑：[相关条目](../学习答疑.md)
