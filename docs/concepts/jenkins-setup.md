# Jenkins CI/CD

> 自动化构建、测试、部署的"流水线引擎"——代码 push 到 GitHub，Jenkins 自动拉取并部署

## 📅 所属阶段

[阶段4: CI/CD 自动化](../学习路线.md#sec-4) — 子阶段 4.4

## 💡 核心概念

### 是什么

Jenkins 是一个开源的**持续集成/持续部署（CI/CD）**工具。它监听代码仓库的变化，自动执行你定义的流程——拉代码、运行测试、构建镜像、部署到服务器。

### 为什么重要

| 没有 Jenkins | 有 Jenkins |
|---|---|
| 手动 `git pull` + 手动 `docker compose up` | push 即部署 |
| 部署步骤靠人记，容易出错 | Pipeline 写死，每次一模一样 |
| 不知道哪次部署引入了 bug | 每次构建有记录，可回溯 |

### 核心原理

```
开发者 git push → GitHub → Webhook → Jenkins 收到通知
                                        ↓
                              Pipeline 执行：
                              1. git clone 拉代码
                              2. docker build 构建镜像
                              3. docker compose up -d 部署
                              4. 通知结果（邮件/企业微信）
```

**关键概念：**

| 概念 | 是什么 | 类比 |
|---|---|---|
| Job / Item | 一个自动化任务（构建、部署） | 一个"剧本" |
| Pipeline | 用代码写的 Job（Jenkinsfile） | Infrastructure as Code 的 CI 版 |
| Webhook | GitHub 通知 Jenkins "有新代码了" | 门铃 |
| Plugin | Jenkins 的功能扩展 | Chrome 扩展 |
| Agent / Node | 执行 Job 的机器 | 工人 |

## 🛠 实践

### 本项目部署方式

Jenkins 本身也跑在 Docker 里，通过 `docker-compose.jenkins.yml` 管理：

```bash
# 构建镜像（首次 3 分钟）
docker-compose -f docker-compose.jenkins.yml build

# 启动
docker-compose -f docker-compose.jenkins.yml up -d

# 取初始密码
docker logs myapp-jenkins | grep -A5 "initialAdminPassword"

# 停止
docker-compose -f docker-compose.jenkins.yml down

# 彻底清数据重来
docker-compose -f docker-compose.jenkins.yml down -v
```

**访问：** `http://localhost:8082`

### 自定义镜像做了什么

```
docker/jenkins/
├── Dockerfile              # 基于 jenkins/jenkins:lts-jdk17
│   ├── 安装 Docker CLI     # 让 Jenkins 能调宿主机 Docker
│   ├── 安装 Git            # Pipeline 拉代码
│   └── 复制镜像源配置      # 切清华源，加速插件下载
└── init.groovy.d/
    └── mirror.groovy       # 启动时自动切换更新中心 URL
```

### Pipeline 示例（后续接入）

```groovy
pipeline {
    agent any
    stages {
        stage('拉代码') {
            steps {
                git 'https://github.com/yourname/myapp.git'
            }
        }
        stage('部署') {
            steps {
                sh 'docker-compose up -d'
            }
        }
    }
}
```

## ⚠️ 踩坑记录

### 坑1：插件安装大量失败（38 个）

**现象：** 安装推荐插件时，大部分下载失败，日志显示：
```
Caused: java.io.IOException: Failed to download from
https://updates.jenkins.io/download/plugins/... → 连接超时
```

**原因：** Jenkins 官方更新中心在国内被墙，默认下载源不可达

**解决：**

```bash
# 直接写镜像源配置到容器
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

或者在网页里手动改：`Manage Jenkins → Plugins → Advanced → Update Site`

### 坑2：init.groovy.d 镜像脚本报错

**现象：** 容器日志显示 `Failed to run script file:/var/jenkins_home/init.groovy.d/mirror.groovy`

**原因：** 脚本里用了 `Jenkins.instance` 但只 import 了 `JenkinsLocationConfiguration`，缺少 `import jenkins.model.Jenkins`

**解决：** 修正 import 语句：
```groovy
import jenkins.model.Jenkins          // ← 必须加这行
import hudson.model.UpdateCenter
```

### 坑3：docker.exe 是 Windows 格式

**现象：** `docker/jenkins/docker.exe` 是 Windows PE 可执行文件（43MB），挂到 Linux 容器无法运行

**原因：** 从 Windows 宿主机复制的 Docker CLI 二进制是 Windows 格式，Linux 容器无法执行 PE 文件

**解决：** 在 Dockerfile 里直接下载 Linux 版 Docker CLI：
```dockerfile
RUN curl -fsSL "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/x86_64/docker-27.3.1.tgz" \
    -o /tmp/docker.tgz && \
    tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1
```

### 坑4：`docker exec -it` 在 Git Bash 报 TTY 错误

**现象：** `the input device is not a TTY. If you are using mintty...`

**原因：** Git Bash（mintty）不支持 `-it` 的 TTY 分配

**解决：** 去掉 `-it` 或者加 `winpty` 前缀：
```bash
winpty docker exec -it myapp-jenkins bash
# 或不用交互式：
docker exec myapp-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## 🔗 关联

- 学习路线：[阶段4 CI/CD](../学习路线.md#sec-4) — 4.4 Jenkins Pipeline
- 学习路线：[阶段5 Harbor](../学习路线.md#sec-5) — 私有镜像仓库，接入 Jenkins
- 答疑：[阶段4 FAQ](../学习答疑.md)
- 容器化基础：[多阶段构建](docker-multi-stage.md)、[Compose 进阶](compose-advanced.md)
