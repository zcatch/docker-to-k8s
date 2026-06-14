# Docker 数据管理

> Volume 持久化数据、Bind Mount 同步代码——两种挂载各司其职

## 📅 所属阶段

[阶段2: 容器化进阶](../学习路线.md#sec-8) — 子阶段 2.5

## 💡 核心概念

### 是什么

Docker 容器的文件系统是临时的——容器删除，写入的数据就没了。Volume 和 Bind Mount 是把宿主机目录/卷挂载到容器内的机制，实现数据持久化。

### 为什么重要

- 数据库容器重建后数据还在（Volume）
- 代码改动实时反映到容器，不用每次重建镜像（Bind Mount）
- 选错挂载方式会有性能问题——Windows 上尤其明显

### 核心原理

**Volume vs Bind Mount：**

| | Bind Mount | Named Volume |
|------|:---:|:---:|
| Compose 写法 | `- ./path:/container/path` | `- volume_name:/container/path` |
| 数据位置 | 宿主机指定路径 | Docker 管理（`/var/lib/docker/volumes/`） |
| 宿主机直接编辑 | ✅ | ❌ |
| 容器删除后 | 文件保留在宿主机 | 卷保留，下次自动挂回 |
| Windows IO 性能 | 较差（跨文件系统） | 好（WSL2 原生） |
| 适合放 | 代码、配置文件 | 数据库、用户上传文件 |

**命名卷 vs 匿名卷：**
- 命名卷：compose 中显式声明名称（如 `mysql-data`），可追溯可管理
- 匿名卷：容器删除时的残留，`docker volume ls` 中显示为随机哈希名
- `docker volume prune -f` 清理所有无主匿名卷

## 🛠 实践

### 本项目中的应用

```yaml
services:
  mysql:
    volumes:
      - mysql-data:/var/lib/mysql    # 命名卷 — 数据持久化

  php:
    volumes:
      - ./public:/var/www/html/public  # Bind Mount — 代码同步

volumes:
  mysql-data:                          # 显式声明命名卷
```

### 备份 MySQL 数据卷

```bash
# 临时启动一个容器，挂载 mysql-data 卷，打包数据
docker run --rm -v myapp_mysql-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/mysql-backup.tar.gz -C /data .
```

## ⚠️ 踩坑记录

### 坑：Windows 上代码改动延迟很大

**现象：** 改代码后等好几秒才反映到容器

**原因：** Bind Mount 在 Windows ↔ WSL2 之间跨文件系统 IO 性能差

**解决：** 代码放 WSL2 内，或使用 Compose Watch 的 sync 模式替代 Bind Mount

## 🔗 关联

- [Compose Watch](compose-watch.md) — 替代 Bind Mount 的开发体验
- 学习路线：[阶段2](../学习路线.md#sec-8)
- 答疑：[相关条目](../学习答疑.md)
