# Jenkins CI/CD — 自定义镜像
# 解决两个问题：
#   1. 安装 Docker CLI（Linux 版），让 Jenkins 能调用宿主机 Docker
#   2. 配置清华镜像源，加速插件下载

FROM jenkins/jenkins:lts-jdk17

USER root

# ── 安装 Docker CLI ──
# 只装 CLI 二进制（~25MB），不装 Docker Engine
# Jenkins 通过 /var/run/docker.sock 调用宿主机的 Docker Engine
RUN curl -fsSL "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/x86_64/docker-27.3.1.tgz" \
    -o /tmp/docker.tgz && \
    tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1 && \
    chmod +x /usr/local/bin/docker && \
    rm /tmp/docker.tgz && \
    docker --version

# ── 安装 Docker Compose（独立二进制）──
RUN curl -fsSL "https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    docker-compose version

# ── 安装 Git（Pipeline 拉代码用）──
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# ── 设置清华镜像源（解决插件下载慢/失败）──
COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

USER jenkins
