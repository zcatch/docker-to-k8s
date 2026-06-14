// Jenkins 启动时自动设置国内镜像源
// 解决插件安装时 "装不了" 的问题

import jenkins.model.Jenkins
import hudson.model.UpdateCenter

def uc = Jenkins.instance.updateCenter
def defaultSite = uc.sites[0]

// 清华镜像（比官方源快 10 倍）
defaultSite.url = 'https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json'

println "✅ Jenkins 更新中心已切换到清华镜像: ${defaultSite.url}"
