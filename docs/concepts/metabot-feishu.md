# MetaBot 与飞书接入

> 通过 MetaBot 桥接服务，在飞书手机上用 Claude Code 写代码、管 Agent、自动化一切

## 📅 所属阶段

阶段4：CI/CD 自动化（扩展实践）

## 💡 核心概念

### 是什么

MetaBot 是一个桥接服务（Node.js/TypeScript），连接 IM 平台（飞书/Lark、Telegram、微信）到 AI 编码 Agent SDK（Claude Code / Kimi Code / Codex CLI）。用户在飞书聊天窗口发消息，MetaBot 转发给 Claude Code，Claude 执行代码操作，结果通过飞书流式卡片实时返回。

### 为什么重要

- **移动端编码**：手机上通过飞书指挥 Claude Code 写代码、修 bug、部署
- **Agent 团队**：支持多 Bot 并行，每个 Bot 独立工作目录 + 独立引擎，相当于多个 AI 员工同时干活
- **无需公网 IP**：飞书走 WebSocket 长连接，Telegram 走长轮询，NAT/防火墙后直接跑
- **持久会话**：`METABOT_PERSISTENT_EXECUTOR` 让子 Agent 和后台任务跨消息存活

### 核心原理

```
飞书 App (手机) ──WebSocket──▶ 飞书服务器 ──事件推送──▶ MetaBot (本地)
                                                          │
                                                    启动子进程 claude
                                                          │
                                                  Claude Agent SDK
                                                     (读写代码)
```

MetaBot 不代理 AI 请求——它只是一个**消息翻译层**。飞书消息 → MetaBot 解析 → 调 Claude Agent SDK（本地子进程）→ Claude 自主执行工具调用 → 结果翻译成飞书卡片返回。

---

## 🛠 1. 安装 MetaBot

```bash
# 一键安装（推荐）
curl -fsSL https://raw.githubusercontent.com/xvirobotics/metabot/main/install.sh | bash

# 或手动克隆
git clone https://github.com/xvirobotics/metabot.git
cd metabot && npm install
```

前置条件：
- Node.js 20+
- Claude Code CLI 已安装并认证：`npm install -g @anthropic-ai/claude-code && claude login`

---

## 🛠 2. 飞书应用配置

### 2.1 创建飞书应用

1. 进入 [飞书开放平台](https://open.feishu.cn/app) → 创建自定义应用
2. 左侧「添加功能」→ 添加「机器人」能力
3. 左侧「权限管理」→ 添加权限：
   - `im:message` — 收发消息
   - `im:message:readonly` — 读取消息
   - `im:resource` — 上传图片/文件
   - `im:chat:readonly` — 读取群信息
4. 左侧「事件与回调」→ 选择「使用长连接接收事件」→ 添加 `im.message.receive_v1` 事件
5. 顶部「创建版本」→ 发布（版本号如 `1.0.0`）

### 2.2 记录凭证

在应用主页「凭证与基础信息」复制 **App ID**（如 `cli_xxxx`）和 **App Secret**。

### 2.3 配置 MetaBot

单 Bot 模式（`.env`）：

```env
FEISHU_APP_ID=cli_aaa727523738dbe5
FEISHU_APP_SECRET=PbABs2MFAhfhPFxdh6sU2ds7cmjflJvx
CLAUDE_DEFAULT_WORKING_DIRECTORY=D:\phpstudy_pro\WWW\myapp
METABOT_PERSISTENT_EXECUTOR=true
```

多 Bot 模式（`bots.json`，此时 `.env` 中的 `FEISHU_APP_*` 被忽略）：

```json
{
  "feishuBots": [{
    "name": "my-bot",
    "feishuAppId": "cli_xxx",
    "feishuAppSecret": "...",
    "defaultWorkingDirectory": "/home/user/project"
  }]
}
```

### ⚠️ 事件订阅必须先启动服务

飞书「长连接」模式保存时会立即验证 WebSocket 连接。如果 MetaBot 还没跑起来，保存会失败。**先 `npm run dev` 启动服务，再配置事件。**

### ⚠️ 应用发布后搜不到机器人

发布后需要**退出飞书重新登录**，才能在搜索栏搜到机器人名字。这是飞书客户端的缓存机制。

---

## 🛠 3. 启动与使用

```bash
# 开发模式（热重载）
npm run dev

# 生产模式
npm run build && npm start

# 更新
metabot update
```

启动后在飞书搜索机器人名字，发消息即可。Claude 的响应会以流式卡片形式实时更新。

### 常用飞书命令

| 命令 | 作用 |
|------|------|
| `/reset` | 重置当前会话（清空上下文） |
| `/status` | 查看当前任务状态 |
| `/background 任务描述` | 启动后台任务 |
| `/goal 目标` | 启动自主循环目标 |
| `/model opus/sonnet/haiku` | 切换模型 |
| `/memory list/search` | 查询持久记忆 |

---

## 🛠 4. 本项目的 MetaBot 配置

MetaBot 安装在本项目的 `metabot/` 目录下，工作目录指向项目根：

```env
# metabot/.env 关键配置
FEISHU_APP_ID=cli_aaa727523738dbe5
CLAUDE_DEFAULT_WORKING_DIRECTORY=D:\phpstudy_pro\WWW\myapp
CLAUDE_EXECUTABLE_PATH=D:\soft\nodejs\node_modules\@anthropic-ai\claude-code\bin\claude.exe
METABOT_PERSISTENT_EXECUTOR=true
SCHEDULE_TIMEZONE=Asia/Shanghai
API_PORT=9100
META_MEMORY_URL=http://localhost:8100
```

关键决策：
- `METABOT_PERSISTENT_EXECUTOR=true`：启用持久执行器，子 Agent（Agent Team）跨消息存活
- `CLAUDE_DEFAULT_WORKING_DIRECTORY` 指向本项目根目录，Claude 在此上下文中工作
- API 端口 `9100`，MetaMemory 端口 `8100`

### ⚠️ Windows 下 Claude CLI 路径

Windows 上 `claude` 命令是 `.cmd` 包装器，不能直接在 Node.js 子进程中 spawn。MetaBot 通过 `CLAUDE_EXECUTABLE_PATH` 指向实际的可执行文件（`claude.exe`）。

### ⚠️ MetaBot 与项目 git 的关系

MetaBot 本身是一个独立项目，有自己的 git 仓库。把它放在项目 `metabot/` 目录下是为了方便管理。需要确保 `metabot/node_modules/` 和 `metabot/.env`（含飞书密钥）不被提交到本项目 git。

---

## 📁 文件索引

| 文件 | 用途 |
|------|------|
| `metabot/.env` | 飞书 App ID/Secret、工作目录、引擎配置 |
| `metabot/bots.json` | 多 Bot 配置（存在时忽略 .env 中的飞书凭证） |
| `metabot/src/feishu/` | 飞书消息处理、卡片构建、事件处理器 |
| `metabot/src/engines/claude/` | Claude Code 执行器、会话管理、流处理 |
| `metabot/docs/` | MetaBot 完整文档（中英双语） |

## 🔗 关联

- 学习路线：[阶段4](../学习路线.md#sec-4)
- 答疑：[Q018-Q019](../学习答疑.md)
- MetaBot 文档站：<https://xvirobotics.com/metabot/zh/>
