# Jenkins CI/CD

> 自动化构建、测试、部署的"流水线引擎"——代码 push 到 GitHub，Jenkins 自动拉取并部署

## 📅 所属阶段

[阶段4: CI/CD 自动化](../学习路线.md#sec-4) — 子阶段 4.4

## 💡 核心概念

### 是什么

Jenkins 是一个开源的**持续集成/持续部署（CI/CD）**工具。它监听代码仓库的变化，自动执行你定义的流程——拉代码、运行测试、构建镜像、部署到服务器。

**关键概念：**

| 概念 | 是什么 | 类比 |
|---|---|---|
| Job / Item | 一个自动化任务（构建、部署） | 一个"剧本" |
| Pipeline | 用代码写的 Job | Infrastructure as Code 的 CI 版 |
| Webhook | GitHub 通知 Jenkins "有新代码了" | 门铃 |
| Plugin | Jenkins 的功能扩展 | Chrome 扩展 |
| Script Approval | 每次改脚本需手动审批 | sudo 输入密码 |

### 完整流程

```
git push → GitHub → Jenkins 拉代码 → docker-compose up -d --build → 部署完成
```

---

## 🛠 1. 部署 Jenkins 自身

Jenkins 本身也跑在 Docker 里：

```bash
docker-compose -f docker-compose.jenkins.yml build
docker-compose -f docker-compose.jenkins.yml up -d
docker logs myapp-jenkins | grep -A5 "initialAdminPassword"   # 取密码
```

访问 `http://localhost:8082`。

### ⚠️ 插件安装全部失败

第一次安装推荐插件时，38 个插件下载失败，日志显示 `Failed to download from updates.jenkins.io`。

**原因：** Jenkins 官方更新中心在国内被墙。

**解决：**
```bash
docker exec myapp-jenkins sh -c 'cat > /var/jenkins_home/hudson.model.UpdateCenter.xml << EOF
<?xml version="1.1" encoding="UTF-8"?>
<sites>
  <site>
    <id>default</id>
    <url>https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json</url>
  </site>
</sites>
EOF'
```

或者在网页里：`Manage Jenkins → Plugins → Advanced → Update Site`，填入清华镜像 URL。

### ⚠️ 镜像源自动切换脚本没生效

写了 `docker/jenkins/init.groovy.d/mirror.groovy` 期望启动时自动切镜像，但日志报 `Failed to run script: No such property: Jenkins`。

**原因：** 脚本用了 `Jenkins.instance` 但只 import 了 `JenkinsLocationConfiguration`，缺 `import jenkins.model.Jenkins`。

**解决：**
```groovy
import jenkins.model.Jenkins          // 必须加
import hudson.model.UpdateCenter
```

> 💡 即使脚本正确，它也可能在 setup wizard 之后才执行——最可靠的方式还是直接写 XML 文件。

---

## 🛠 2. 自定义 Jenkins 镜像

基础镜像 `jenkins/jenkins:lts-jdk17` 缺少 Docker CLI、Git、Compose。通过 Dockerfile 扩展：

```
docker/jenkins/
├── Dockerfile              # 基于 jenkins/jenkins:lts-jdk17
│   ├── 安装 Docker CLI     # Linux 静态二进制，调宿主机 Docker Engine
│   ├── 安装 Docker Compose # 独立二进制（非 docker compose 插件）
│   └── 安装 Git            # Pipeline 拉代码
└── init.groovy.d/
    └── mirror.groovy       # 启动时切换更新中心 URL
```

### ⚠️ docker.exe 是 Windows 格式

`docker/jenkins/docker.exe`（43MB）是 Windows PE 文件，挂到 Linux 容器无法执行。

**原因：** 从 Windows 宿主机复制的 Docker CLI 是 PE 格式，Linux 不认。

**解决：** 在 `docker/jenkins/Dockerfile` 里直接下载 Linux 版：
```dockerfile
RUN curl -fsSL "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/x86_64/docker-27.3.1.tgz" \
    -o /tmp/docker.tgz && \
    tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1
```

### ⚠️ Git Bash 执行 `docker exec -it` 报 TTY 错误

`the input device is not a TTY. If you are using mintty...`

**原因：** Git Bash（mintty）不支持 `-it` 的 TTY 分配。

**解决：** 加 `winpty` 前缀，或非交互场景直接去掉 `-it`：
```bash
winpty docker exec -it myapp-jenkins bash
docker exec myapp-jenkins cat /path/to/file    # 不交互，不用 -it
```

---

## 🛠 3. 写第一个 Pipeline

### 新建任务

`新建任务` → 任务名 `myapp-deploy` → 选 **流水线（Pipeline）** → 确定。

### 编写脚本

拉到 **Pipeline** 区域，定义选 `Pipeline script`，**取消勾选"使用 Groovy 沙盒"**（沙盒会拦截 sh 命令）：

```groovy
pipeline {
    agent any
    stages {
        stage('拉代码') {
            steps {
                git branch: 'master', url: 'https://github.com/zcatch/docker-to-k8s.git'
            }
        }
        stage('部署') {
            steps {
                sh """
                    cd ${WORKSPACE}
                    cp .env.example .env
                    docker stop myapp-php myapp-nginx myapp-mysql myapp-redis myapp-adminer 2>/dev/null || true
                    docker rm myapp-php myapp-nginx myapp-mysql myapp-redis myapp-adminer 2>/dev/null || true
                    docker-compose -f docker-compose.jenkins-full.yml up -d --build
                """
            }
        }
    }
}
```

保存 → **立即构建**。

### ⚠️ 保存时提示 "The script is not approved"

**原因：** Jenkins 安全机制——Pipeline 可以执行任意 shell 命令，每次修改都必须管理员审批。

**解决：** 忽略警告直接保存 → `Manage Jenkins → In-process Script Approval → Approve` → 再构建。每次脚本改动（哪怕一个字符）都要重新审批。

> 💡 后续可把 Pipeline 改成 Jenkinsfile 存在 Git 仓库里，Jenkins 自动拉取执行，不用手动贴脚本。

---

## 🛠 4. Jenkins 部署应用

### Docker-out-of-Docker 架构

```
Jenkins 容器（有 docker CLI）── docker.sock ──→ 宿主机 Docker Engine
```

Jenkins 通过 `/var/run/docker.sock` 调用宿主机 Docker。CLI 在容器里，Engine 在宿主机上。

### ⚠️ docker compose 命令报 "unknown shorthand flag"

第一次构建报 `docker: 'compose' is not a docker command` 或 `unknown shorthand flag: 'd' in -d`。

**原因：** 静态安装的 Docker CLI 不包含 Compose 插件。`docker compose`（空格）需要 CLI 插件支持。

**解决：** 装独立版 `docker-compose`（带连字符）：
```bash
# 宿主机下载（走 GitHub 代理），再 cp 进容器
curl -fsSL "https://ghproxy.net/https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-linux-x86_64" \
    -o /tmp/docker-compose-linux
docker cp /tmp/docker-compose-linux myapp-jenkins:/usr/local/bin/docker-compose
docker exec myapp-jenkins chmod +x /usr/local/bin/docker-compose
```

Pipeline 里命令用 `docker-compose`（带连字符），不是 `docker compose`。

### ⚠️ bind mount 路径报 not a directory

Jenkins 构建时 compose 报：
```
error mounting "/var/jenkins_home/workspace/myapp-deploy/docker/php/www.conf"
→ not a directory: unknown: Are you trying to mount a directory onto a file?
```

**原因：** Docker-out-of-Docker 的路径翻译问题。Compose 文件里 `./docker/php/www.conf` 在 Jenkins 容器内解析为 `/var/jenkins_home/workspace/.../www.conf`，Docker Engine 去宿主机上找这个路径——宿主机根本没有。

```
Jenkins 容器解析: ./docker/php/www.conf → /var/jenkins_home/workspace/.../www.conf
Docker Engine 去找: /var/jenkins_home/workspace/.../www.conf → ❌ 不存在
```

**解决：** 创建 `docker-compose.jenkins-full.yml`（项目根目录），完全去掉 bind mount。PHP 配置文件在 `Dockerfile` 里 `COPY` 进镜像，Nginx 配置在 `docker/nginx/Dockerfile` 里打入镜像，都不依赖外部挂载。

### ⚠️ 部署后访问 8080 显示 File not found

**原因：** Dockerfile 只 COPY 了配置（php.ini、www.conf），没 COPY 应用代码 `public/`。开发环境靠 `develop.watch` 同步代码，Jenkins 部署没有。

**解决：** 在项目根目录 `Dockerfile` 里补上（第 78 行 `WORKDIR` 之前）：
```dockerfile
COPY ./public /var/www/html/public
```

push 到 GitHub 后 Jenkins 重新构建即可。

---

## 📁 项目文件索引

| 文件 | 用途 |
|---|---|
| `docker-compose.jenkins.yml` | Jenkins 自身服务 |
| `docker-compose.jenkins-full.yml` | Jenkins 部署目标（无 bind mount，独立 compose） |
| `docker/jenkins/Dockerfile` | Jenkins 自定义镜像（Docker CLI + Compose + Git + 镜像源） |
| `docker/jenkins/init.groovy.d/mirror.groovy` | 启动时切清华镜像（辅助，不一定生效） |
| `docker/nginx/Dockerfile` | 自定义 Nginx 镜像（配置打入镜像，避免 bind mount） |

## 🔗 关联

- 学习路线：[阶段4 CI/CD](../学习路线.md#sec-4)
- 学习路线：[阶段5 Harbor](../学习路线.md#sec-5)
- 答疑：[阶段4 FAQ](../学习答疑.md)
- 容器化基础：[多阶段构建](docker-multi-stage.md)、[Compose 进阶](compose-advanced.md)
