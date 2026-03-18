"""
OpenClaw Bridge 配置集中管理
统一管理模型、超时、心跳间隔、Skill 目录等常量
"""

import os
from pathlib import Path

# ==================== 路径配置 ====================
# OpenClaw 根目录
OPENCLAW_ROOT = Path(os.environ.get("OPENCLAW_ROOT", "/Users/jason/.openclaw"))

# Skills 目录 (workspace/skills)
SKILLS_DIR = OPENCLAW_ROOT / "workspace" / "skills"

# Bridge 工作目录
BRIDGE_WORK_DIR = OPENCLAW_ROOT / "workspace" / "projects" / "bridge" / "runs"

# Claude Code 配置
CLAUDE_CONFIG_DIR = OPENCLAW_ROOT / ".claude"

# ==================== 模型配置 ====================
# 默认模型
DEFAULT_MODEL = os.environ.get("CLAUDE_MODEL", "sonnet")

# 支持的模型列表
SUPPORTED_MODELS = ["sonnet", "opus", "haiku"]

# ==================== 超时配置 ====================
# 执行超时（秒）
EXECUTION_TIMEOUT = int(os.environ.get("BRIDGE_EXECUTION_TIMEOUT", "600"))

# 心跳间隔（秒）
HEARTBEAT_INTERVAL = int(os.environ.get("BRIDGE_HEARTBEAT_INTERVAL", "30"))

# 状态检查间隔（秒）
STATE_CHECK_INTERVAL = int(os.environ.get("BRIDGE_STATE_CHECK_INTERVAL", "5"))

# PID 存活检测超时（秒）
PID_CHECK_TIMEOUT = int(os.environ.get("BRIDGE_PID_CHECK_TIMEOUT", "10"))

# ==================== 安全规则配置 ====================
# 禁止访问的敏感目录
FORBIDDEN_DIRS = [
    "/.ssh",
    "/.aws",
    "/.gnupg",
    "/.npm/_cacache",
    "/.cache/pip",
    "/.token",
    "/private",
    "/etc/passwd",
    "/etc/shadow",
]

# 禁止的全盘搜索模式
FORBIDDEN_PATTERNS = [
    "**/.ssh/**",
    "**/.aws/**",
    "**/.gnupg/**",
    "**/.token/**",
    "**/credentials*",
    "**/password*",
    "**/secret*",
    "**/id_rsa*",
    "**/id_ed25519*",
]

# 必须先读取的文件
REQUIRED_FILES = ["SKILL.md"]

# ==================== 通知配置 ====================
# 通知回调命令模板
NOTIFY_CMD_TEMPLATE = "openclaw agent --deliver {agent_id} --message {message}"

# 默认飞书机器人 webhook（可选）
FEISHU_WEBHOOK = os.environ.get("FEISHU_WEBHOOK", "")

# ==================== 状态定义 ====================
class State:
    STARTING = "starting"
    RUNNING = "running"
    DONE = "done"
    ERROR = "error"
    KILLED = "killed"


# ==================== 通信协议标记 ====================
PROTOCOL_STARTING = "[BRIDGE:STARTING]"
PROTOCOL_RUNNING = "[BRIDGE:RUNNING]"
PROTOCOL_DONE = "[BRIDGE:DONE]"
PROTOCOL_ERROR = "[BRIDGE:ERROR]"
PROTOCOL_KILLED = "[BRIDGE:KILLED]"
PROTOCOL_HEARTBEAT = "[BRIDGE:HEARTBEAT]"


# ==================== SDK 配置 ====================
# Claude Agent SDK 配置
SDK_MAX_TOKENS = int(os.environ.get("CLAUDE_MAX_TOKENS", "4096"))
SDK_TEMPERATURE = float(os.environ.get("CLAUDE_TEMPERATURE", "1.0"))

# ==================== 其他配置 ====================
# 是否启用调试模式
DEBUG_MODE = os.environ.get("BRIDGE_DEBUG", "false").lower() == "true"

# 最大并发任务数
MAX_CONCURRENT_TASKS = int(os.environ.get("BRIDGE_MAX_CONCURRENT", "5"))

# 状态文件原子写入的临时文件后缀
TMP_STATE_SUFFIX = ".tmp"
