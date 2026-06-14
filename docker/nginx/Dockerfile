# Nginx 自定义镜像 — 配置直接打入镜像
# 避免 Jenkins 部署时 bind mount 路径问题

FROM nginx:1.27-alpine
COPY default.conf /etc/nginx/conf.d/default.conf
