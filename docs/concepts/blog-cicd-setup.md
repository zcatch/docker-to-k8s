# 博客项目 CI/CD 接入

> 将已有的 Vue 个人博客项目接入 Jenkins 自动部署——从本地 `web_code` 到 GitHub `blog-cms`

## 📅 所属阶段

[阶段4: CI/CD 自动化](../学习路线.md#sec-4) — 第二个实践项目

## 💡 核心概念

### 与 myapp 的对比

| | myapp (PHP) | blog-cms (Vue) |
|---|---|---|
| 技术栈 | PHP-FPM + Nginx + MySQL + Redis | Vue 3 + Vite → 静态 HTML |
| 容器数 | 4 个 | 1 个 |
| 构建方式 | 多阶段 Alpine（编译 PHP 扩展） | 多阶段（Node 编译 → Nginx 运行） |
| 配置管理 | bind mount（开发） | 全部 COPY 进镜像 |
| 端口 | 8080 | 8083 |
| Git 分支 | `master` | `main` |

博客的 Dockerfile 比 myapp 干净——所有内容都通过 `COPY` 打入镜像，不存在 bind mount 路径问题。

---

## 🛠 1. Git 仓库迁移

### 调整过程

原项目在 `D:\phpstudy_pro\WWW\self\web_code`，已关联 `zcatch/web_code`。改为新仓库 `zcatch/blog-cms`：

```bash
cd /d/phpstudy_pro/WWW/self/web_code
git remote set-url origin git@github.com:zcatch/blog-cms.git
git push -u origin main
```

### ⚠️ 仓库命名：blog-cms 还是 blog-cms-？

创建时不小心加了末尾横杠，导致 `git push` 报 `Repository not found`。

**解决：** 确认 GitHub 上的实际仓库名，用正确的 SSH URL 重新 `git remote set-url`。

### ⚠️ `__pycache__` 被误提交

Git add 时 Python 缓存文件被打包进仓库。

**解决：** 在 `web/.gitignore` 追加 `__pycache__/`，然后 `git rm --cached` 移除：
```bash
echo "__pycache__/" >> web/.gitignore
git rm -r --cached web/.agent/skills/ui-ux-pro-max/scripts/__pycache__/
git commit -m "chore(git): exclude __pycache__ from version control"
```

### 提交历史

```
e019eec fix(docker): override vite outDir to dist for Docker build
63e33f2 chore(git): exclude __pycache__ from version control
8cc15f5 feat(docker): add multi-stage Dockerfile and compose for blog deployment
```

---

## 🛠 2. Dockerfile 分析

文件位置：`web/Dockerfile`（项目根目录的 `web/` 子目录下）

```dockerfile
# 阶段 1: Node 构建
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install              # 装 Vue/Vite/Element Plus 等依赖
COPY . .
RUN npm run build -- --outDir dist   # Vite 编译 → dist/

# 阶段 2: Nginx 运行
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html   # 静态文件
COPY nginx.conf /etc/nginx/conf.d/default.conf         # Nginx 配置
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**优点：**
- 多阶段构建：Node + npm 在 builder 阶段丢弃，最终镜像只有 Nginx
- 全部 `COPY`：代码和配置都在镜像里，无 bind mount 依赖
- SPA 友好：`nginx.conf` 里配了 `try_files $uri /index.html`

### ⚠️ Vite 构建产物找不到

Jenkins 构建报 `COPY failed: stat app/dist: file does not exist`。

**原因：** `vite.config.js` 里自定义了输出路径：
```js
build: {
    outDir: path.resolve(__dirname, '../../web_deploy/web'),  // 输出到项目外的目录！
}
```

本地开发时产物写到相邻的 `web_deploy/` 目录，方便本地预览。但 Docker 构建时这个路径在容器里无效，`/app/dist` 不存在。

**解决：** 在 `web/Dockerfile` 第 17 行，用 CLI 参数覆盖 `vite.config.js` 的配置：
```dockerfile
RUN npm run build -- --outDir dist
```

`--` 把后面的参数传给 `vite build`，`--outDir dist` 强制输出到标准的 `dist/`。

> 不改 `vite.config.js`（保留本地开发习惯），只在 Dockerfile 里覆盖。

---

## 🛠 3. Jenkins Pipeline

在 Jenkins 新建第二个 Job：`blog-cms-deploy`

```groovy
pipeline {
    agent any
    stages {
        stage('拉代码') {
            steps {
                git branch: 'main', url: 'https://github.com/zcatch/blog-cms.git'
            }
        }
        stage('构建部署') {
            steps {
                sh """
                    cd ${WORKSPACE}/web
                    docker stop blog-cms 2>/dev/null || true
                    docker rm blog-cms 2>/dev/null || true
                    docker build -t blog-cms:latest .
                    docker run -d --name blog-cms -p 8083:80 blog-cms:latest
                """
            }
        }
    }
}
```

**与 myapp Pipeline 的区别：**

| | myapp-deploy | blog-cms-deploy |
|---|---|---|
| 分支 | `master` | `main` |
| 子目录 | 无（项目在根目录） | `web/` |
| 部署方式 | `docker-compose up -d --build` | `docker build` + `docker run` |
| 环境变量 | 需要 `.env`（MySQL/Redis 密码） | 不需要（纯静态） |
| 端口 | 8080 | 8083 |

---

## 📁 文件索引

| 文件 | 用途 |
|---|---|
| `D:\phpstudy_pro\WWW\self\web_code\web\Dockerfile` | 多阶段构建（Node → Nginx） |
| `D:\phpstudy_pro\WWW\self\web_code\web\nginx.conf` | SPA 路由 + gzip + 缓存策略 |
| `D:\phpstudy_pro\WWW\self\web_code\web\docker-compose.yml` | 本地三模式（dev/prod/build） |
| `D:\phpstudy_pro\WWW\self\web_code\web\vite.config.js` | Vite 构建配置（outDir 指向外部目录） |

## 🔗 关联

- 学习路线：[阶段4 CI/CD](../学习路线.md#sec-4)
- myapp Jenkins：[jenkins-setup.md](jenkins-setup.md) — 第一个 Pipeline 的完整踩坑
- 答疑：[阶段4 FAQ](../学习答疑.md)
