# OpenClaw Bridge

一个健壮的、企业级的桥接系统，旨在将 **OpenClaw**（以及其他个人 AI 助手）与具有 Agent 能力的 LLM 接口（如 **Claude Code** 和 **Gemini CLI**）连接起来。

该桥接系统提供了一个受管的执行环境，确保长时运行的 AI 任务具备进程隔离、安全强制执行和可靠的状态追踪能力。

## 主要特性

- **🚀 受管执行**: 在受控环境中封装 LLM SDK/CLI，并配备专门的运行目录。
- **🤖 多后端支持**: 可以在 **Claude Code** (通过 SDK) 和 **Gemini CLI** (通过原生二进制文件) 之间无缝切换。
- **📊 实时状态追踪**: 通过 `state.json` 原子级更新追踪每个阶段：`starting`（启动中）、`running`（运行中）、`done`（完成）、`error`（错误）和 `killed`（已终止）。
- **🛡️ 安全沙箱**: 内置路径验证和模式匹配，防止未经授权访问敏感文件（如 `.ssh`、`.env`、`/etc/passwd`）。
- **⏲️ 健壮性与安全性**:
  - **看门狗定时器 (Watchdog)**: 在可配置的超时后自动终止卡死的进程。
  - **心跳机制**: 为监控工具提供存活信号。
  - **进程清理**: 通过多层信号处理确保不留下“僵尸”进程。
- **🔗 工具拦截**: 专门的逻辑用于拦截并将用户确认工具（如 `AskUserQuestion` 和 Gemini 的 `ask_user`）转发回父 Agent。
- **📡 OpenClaw 原生支持**: 内置 `openclaw agent --deliver` 支持，通知编排器任务完成或发生错误。
- **🔄 同步/异步模式**: 支持阻塞调用和后台执行。

## 项目结构

- `bridge-runner.sh`: 入口点。负责创建运行目录、看门狗监控和进程管理。
- `bridge.sh`: 负责 Python 虚拟环境的激活。
- `bridge.py`: 核心逻辑层。管理 SDK 交互、安全检查和协议通信。
- `config.py`: 模型、后端、超时、安全规则和路径的集中配置。
- `runs/`: 用于存储执行日志 (`output.txt`) 和元数据 (`state.json`) 的有序存储目录。

## 安装

### 前提条件
- Python 3.10+
- `claude-agent-sdk` (用于 Claude 后端)
- `gemini-cli` (用于 Gemini 后端)

### 设置
1. 克隆仓库到你的 OpenClaw 工作区：
   ```bash
   git clone https://github.com/git-tramp/clawbridge.git
   cd clawbridge
   ```
2. 创建并初始化虚拟环境：
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt  # 或 pip install claude-agent-sdk
   ```

## 使用方法

### 基础命令 (Claude - 默认)
```bash
./bridge-runner.sh <skill_name> --args "<参数>"
```

### 使用 Gemini CLI
```bash
./bridge-runner.sh <skill_name> --backend gemini --model auto-gemini-3 --args "<参数>"
```

### 高级选项
```bash
./bridge-runner.sh my-skill \
    --backend gemini \
    --model auto-gemini-3 \
    --timeout 600 \
    --async \
    --args "重构 src/auth.py 中的身份验证逻辑"
```

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `<skill_name>` | 要执行的技能名称（必填） | - |
| `--args "<文本>"` | 传递给技能的参数 | "" |
| `--model <模型>` | 使用的模型 (Claude: sonnet/opus/haiku, Gemini: auto-gemini-3/gemini-2.0-flash-exp) | sonnet |
| `--backend <后端>` | 使用的后端: `claude` 或 `gemini` | claude |
| `--timeout <秒>` | 执行超时时间（秒） | 600 |
| `--heartbeat <秒>` | 心跳间隔（秒） | 30 |
| `--async` | 异步模式（后台运行） | false |
| `-h, --help` | 显示帮助信息 | - |

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `OPENCLAW_ROOT` | OpenClaw 根目录 | `~/.openclaw` |
| `OPENCLAW_BRIDGE_DIR` | Bridge 工作目录 | `./runs` |
| `OPENCLAW_SKILLS_DIR` | Skills 目录 | `${OPENCLAW_ROOT}/workspace/skills` |
| `OPENCLAW_VENV_PATH` | Python 虚拟环境路径 | `./.venv` |
| `OPENCLAW_AGENT_ID` | 用于通知的 Agent ID | - |
| `OPENCLAW_NOTIFY_CMD` | 自定义通知命令 | - |
| `BRIDGE_BACKEND` | 默认后端 (claude/gemini) | claude |
| `CLAUDE_MODEL` | 默认 Claude 模型 | sonnet |
| `GEMINI_MODEL` | 默认 Gemini 模型 | auto-gemini-3 |
| `GEMINI_PATH` | Gemini CLI 可执行文件路径 | gemini |
| `GEMINI_APPROVAL_MODE` | Gemini 审批模式 (default/auto_edit/yolo/plan) | yolo |
| `BRIDGE_EXECUTION_TIMEOUT` | 默认执行超时（秒） | 600 |
| `BRIDGE_HEARTBEAT_INTERVAL` | 默认心跳间隔（秒） | 30 |
| `BRIDGE_DEBUG` | 启用调试模式 (true/false) | false |

## 与 OpenClaw 集成

OpenClaw Agent 可以将此桥接器作为”Shell 工具”或通过专用提供程序调用。桥接器通过以下方式与 OpenClaw 通信：
1. **退出代码**: 标准 Unix 退出代码用于表示成功/失败。
2. **协议标记**: 结构化的标准输出标记，如 `[BRIDGE:RUNNING]` 或 `[BRIDGE:ERROR]`。
3. **交付命令**: 完成后自动执行 `openclaw agent --deliver`。

## 状态文件格式

桥接器会在每个运行目录中创建 `state.json` 文件，结构如下：

```json
{
  “state”: “running”,
  “skill”: “my-skill”,
  “args”: “参数”,
  “model”: “sonnet”,
  “run_dir”: “/path/to/runs/my-skill/run-20240318-143000”,
  “timestamp”: “2024-03-18T14:30:00Z”,
  “pid”: 12345,
  “started_at”: “2024-03-18T14:30:00Z”,
  “completed_at”: “2024-03-18T14:35:00Z”
}
```

### 状态值

| 状态 | 说明 |
|------|------|
| `starting` | Bridge 正在初始化 |
| `running` | 技能正在执行 |
| `done` | 技能执行成功 |
| `error` | 发生错误 |
| `killed` | 进程被终止 |

## Skills 目录结构

Skills 必须按以下结构组织在 skills 目录中：

```
skills/
└── <skill_name>/
    ├── SKILL.md          # 必填：技能定义和说明
    ├── README.md         # 可选：技能文档
    └── (其他文件)        # 可选：任何额外资源
```

### SKILL.md 格式

`SKILL.md` 文件应包含：

```markdown
# 技能名称

## 描述
简短的技能描述。

## 用法
如何使用此技能。

## 参数
- param1: 参数说明
- param2: 参数说明
```

### 安全规则

桥接器强制执行安全规则以防止未授权访问：

- **禁止访问的目录**: `/.ssh`, `/.aws`, `/.gnupg`, `/.token`, `/private`, `/etc/passwd`, `/etc/shadow`
- **禁止访问的模式**: `**/.ssh/**`, `**/.aws/**`, `**/.gnupg/**`, `**/credentials*`, `**/password*`, `**/secret*`, `**/id_rsa*`

`SKILL.md` 文件必须存在且不能为空。

## 路线图
- [x] 原生 Gemini CLI 支持（通过 `stream-json` 解析）。
- [ ] 用于监控活动运行的可视化仪表板。
- [ ] 增强的遥测功能，用于追踪 Token 使用情况和成本。

## 许可证
MIT
