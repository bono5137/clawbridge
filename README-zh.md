# OpenClaw Bridge

一个健壮的、企业级的桥接系统，旨在将 **OpenClaw**（以及其他个人 AI 助手）与具有 Agent 能力的 LLM 接口（如 **Claude Code** 和 **Gemini CLI**）连接起来。

该桥接系统提供了一个受管的执行环境，确保长时运行的 AI 任务具备进程隔离、安全强制执行和可靠的状态追踪能力。

## 主要特性

- **🚀 受管执行**: 在受控环境中封装 LLM SDK/CLI，并配备专门的运行目录。
- **📊 实时状态追踪**: 通过 `state.json` 原子级更新追踪每个阶段：`starting`（启动中）、`running`（运行中）、`done`（完成）、`error`（错误）和 `killed`（已终止）。
- **🛡️ 安全沙箱**: 内置路径验证和模式匹配，防止未经授权访问敏感文件（如 `.ssh`、`.env`、`/etc/passwd`）。
- **⏲️ 健壮性与安全性**:
  - **看门狗定时器 (Watchdog)**: 在可配置的超时后自动终止卡死的进程。
  - **心跳机制**: 为监控工具提供存活信号。
  - **进程清理**: 通过多层信号处理确保不留下“僵尸”进程。
- **🔗 工具拦截**: 专门的逻辑用于拦截并将用户确认工具（如 `AskUserQuestion`）转发回父 Agent。
- **📡 OpenClaw 原生支持**: 内置 `openclaw agent --deliver` 支持，通知编排器任务完成或发生错误。
- **🔄 同步/异步模式**: 支持阻塞调用和后台执行。

## 项目结构

- `bridge-runner.sh`: 入口点。负责创建运行目录、看门狗监控和进程管理。
- `bridge.sh`: 负责 Python 虚拟环境的激活。
- `bridge.py`: 核心逻辑层。管理 SDK 交互、安全检查和协议通信。
- `config.py`: 模型、超时、安全规则和路径的集中配置。
- `runs/`: 用于存储执行日志 (`output.txt`) 和元数据 (`state.json`) 的有序存储目录。

## 安装

### 前提条件
- Python 3.10+
- [可选] `claude-agent-sdk` (用于目前的 Claude 实现)
- [可选] `gemini-cli` (用于即将推出的 Gemini 支持)

### 设置
1. 克隆仓库到你的 OpenClaw 工作区：
   ```bash
   git clone https://github.com/your-username/openclaw-bridge.git
   cd openclaw-bridge
   ```
2. 创建并初始化虚拟环境：
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt  # 或 pip install claude-agent-sdk
   ```

## 使用方法

### 基础命令
```bash
./bridge-runner.sh <skill_name> --args "<参数>"
```

### 高级选项
```bash
./bridge-runner.sh my-skill \
    --model sonnet \
    --timeout 600 \
    --async \
    --args "重构 src/auth.py 中的身份验证逻辑"
```

## 与 OpenClaw 集成

OpenClaw Agent 可以将此桥接器作为“Shell 工具”或通过专用提供程序调用。桥接器通过以下方式与 OpenClaw 通信：
1. **退出代码**: 标准 Unix 退出代码用于表示成功/失败。
2. **协议标记**: 结构化的标准输出标记，如 `[BRIDGE:RUNNING]` 或 `[BRIDGE:ERROR]`。
3. **交付命令**: 完成后自动执行 `openclaw agent --deliver`。

## 路线图
- [ ] 原生 Gemini CLI 支持（通过 `stream-json` 解析）。
- [ ] 用于监控活动运行的可视化仪表板。
- [ ] 增强的遥测功能，用于追踪 Token 使用情况和成本。

## 许可证
MIT
