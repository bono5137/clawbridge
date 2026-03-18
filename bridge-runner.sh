#!/bin/bash
#
# OpenClaw Bridge - 进程管理 + 状态追踪层
# 负责创建运行目录、状态管理、PID 存活检测、Watchdog 超时强杀
#

set -e

# ==================== 配置 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_SCRIPT="${SCRIPT_DIR}/bridge.sh"

# 默认配置
DEFAULT_TIMEOUT=600          # 执行超时（秒）
DEFAULT_HEARTBEAT=30         # 心跳间隔（秒）
DEFAULT_STATE_CHECK=5        # 状态检查间隔（秒）
DEFAULT_PID_CHECK=10         # PID 存活检测超时（秒）

# 虚拟环境路径
VENV_PATH="${OPENCLAW_VENV_PATH:-${SCRIPT_DIR}/.venv}"

# 工作目录
WORK_DIR="${OPENCLAW_BRIDGE_DIR:-${SCRIPT_DIR}/runs}"

# ==================== 状态管理 ====================
STATE_STARTING="starting"
STATE_RUNNING="running"
STATE_DONE="done"
STATE_ERROR="error"
STATE_KILLED="killed"

# ==================== 协议标记 ====================
PROTOCOL_STARTING="[BRIDGE:STARTING]"
PROTOCOL_RUNNING="[BRIDGE:RUNNING]"
PROTOCOL_DONE="[BRIDGE:DONE]"
PROTOCOL_ERROR="[BRIDGE:ERROR]"
PROTOCOL_KILLED="[BRIDGE:KILLED]"
PROTOCOL_HEARTBEAT="[BRIDGE:HEARTBEAT]"

# ==================== EXIT Trap（第一层防御） ====================
CLEANUP_PID=""
CLEANUP_RUN_DIR=""

cleanup() {
    local exit_code=$?
    local run_dir="${CLEANUP_RUN_DIR:-${RUN_DIR:-}}"

    if [ -n "${run_dir}" ] && [ -d "${run_dir}" ]; then
        # 检查进程是否还在运行
        if [ -n "${CLEANUP_PID}" ] && kill -0 "${CLEANUP_PID}" 2>/dev/null; then
            # 进程仍在运行，写入 killed 状态
            write_state "${STATE_KILLED}" "killed_by_exit_trap"
            echo "${PROTOCOL_KILLED} Process killed by EXIT trap" >&2

            # 尝试优雅终止
            kill -TERM "${CLEANUP_PID}" 2>/dev/null || true
            sleep 1

            # 强制终止
            kill -9 "${CLEANUP_PID}" 2>/dev/null || true
        fi
    fi

    exit ${exit_code}
}

trap cleanup EXIT

# ==================== 辅助函数 ====================

# 原子写入状态文件（tmp + rename）
write_state() {
    local state="$1"
    local extra="$2"
    local state_file="${RUN_DIR}/state.json"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local pid="${CLEANUP_PID:-$$}"

    # 构建 JSON
    local json="{\"state\":\"${state}\",\"skill\":\"${SKILL_NAME}\",\"args\":\"${SKILL_ARGS}\",\"model\":\"${MODEL}\",\"run_dir\":\"${RUN_DIR}\",\"timestamp\":\"${timestamp}\",\"pid\":${pid}"

    if [ -n "${extra}" ]; then
        json="${json},\"extra\":\"${extra}\""
    fi
    json="${json}}"

    # 写入临时文件
    local tmp_file="${state_file}.tmp"
    echo "${json}" > "${tmp_file}"

    # 原子重命名
    mv "${tmp_file}" "${state_file}"
}

# 读取状态
read_state() {
    local state_file="${RUN_DIR}/state.json"
    if [ -f "${state_file}" ]; then
        cat "${state_file}"
    else
        echo "{}"
    fi
}

# 检查 PID 是否存活
check_pid_alive() {
    local pid="$1"
    if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
        return 0  # 存活
    fi
    return 1  # 不存活
}

# 发送心跳
send_heartbeat() {
    local heartbeat_file="${RUN_DIR}/heartbeat.json"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"${timestamp}\",\"pid\":${CLEANUP_PID:-$$}}" > "${heartbeat_file}"
    echo "${PROTOCOL_HEARTBEAT} ${timestamp}"
}

# Watchdog 监控
run_watchdog() {
    local timeout="$1"
    local start_time
    start_time=$(date +%s)
    local pid="$2"

    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        # 检查是否超时
        if [ ${elapsed} -ge ${timeout} ]; then
            echo "${PROTOCOL_ERROR} Watchdog timeout after ${timeout}s" >&2
            write_state "${STATE_ERROR}" "watchdog_timeout"
            return 1
        fi

        # 检查进程是否存活
        if ! check_pid_alive "${pid}"; then
            return 0  # 进程已结束
        fi

        sleep ${STATE_CHECK_INTERVAL:-${DEFAULT_STATE_CHECK}}
    done
}

# 安全规则检查
check_security_rules() {
    local skill_name="$1"
    # 默认指向 workspace/skills
    local skills_dir="${OPENCLAW_SKILLS_DIR:-${SCRIPT_DIR}/../../.openclaw/workspace/skills}"
    local skill_dir="${skills_dir}/${skill_name}"

    # 检查 SKILL.md 是否存在
    if [ ! -f "${skill_dir}/SKILL.md" ]; then
        echo "${PROTOCOL_ERROR} SKILL.md not found for skill: ${skill_name}" >&2
        return 1
    fi

    # 检查 SKILL.md 是否为空
    if [ ! -s "${skill_dir}/SKILL.md" ]; then
        echo "${PROTOCOL_ERROR} SKILL.md is empty for skill: ${skill_name}" >&2
        return 1
    fi

    return 0
}

# ==================== 主逻辑 ====================

usage() {
    cat << EOF
Usage: $(basename "$0") <skill_name> [args...]

Options:
    --timeout <seconds>     Execution timeout (default: ${DEFAULT_TIMEOUT})
    --heartbeat <seconds>  Heartbeat interval (default: ${DEFAULT_HEARTBEAT})
    --model <model>         Model to use (default: sonnet)
    --async                 Run in async mode
    -h, --help              Show this help

Environment Variables:
    OPENCLAW_BRIDGE_DIR    Bridge working directory
    OPENCLAW_SKILLS_DIR     Skills directory
    OPENCLAW_AGENT_ID       Agent ID for notification

Examples:
    $(basename "$0") my-skill --arg1 value1
    $(basename "$0") my-skill --timeout 300 --model opus
EOF
}

# 解析参数
SKILL_NAME=""
SKILL_ARGS=""
TIMEOUT="${DEFAULT_TIMEOUT}"
HEARTBEAT="${DEFAULT_HEARTBEAT}"
MODEL="sonnet"
ASYNC_MODE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --heartbeat)
            HEARTBEAT="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --async)
            ASYNC_MODE=true
            shift
            ;;
        --args)
            # Special handling for --args: capture everything after it as skill args
            SKILL_ARGS="$2"
            shift 2
            # After --args, remaining args should go to skill, not bridge-runner
            while [ $# -gt 0 ]; do
                SKILL_ARGS="${SKILL_ARGS} $1"
                shift
            done
            break
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            SKILL_NAME="$1"
            shift
            # Everything after skill name goes to skill args
            SKILL_ARGS="$*"
            break
            ;;
    esac
done

# 验证参数
if [ -z "${SKILL_NAME}" ]; then
    echo "Error: skill_name is required" >&2
    usage
    exit 1
fi

# 安全规则检查
if ! check_security_rules "${SKILL_NAME}"; then
    exit 1
fi

# 创建运行目录
RUN_ID="run-$(date +%Y%m%d-%H%M%S)-$$"
RUN_DIR="${WORK_DIR}/${SKILL_NAME}/${RUN_ID}"
mkdir -p "${RUN_DIR}"

echo "Created run directory: ${RUN_DIR}"

# 设置全局变量供 cleanup 使用
CLEANUP_RUN_DIR="${RUN_DIR}"

# 写入初始状态
write_state "${STATE_STARTING}"
echo "${PROTOCOL_STARTING} Skill: ${SKILL_NAME}, Run: ${RUN_ID}"

# 通过环境变量传递参数（避免 shell 引号解析问题）
export OPENCLAW_BRIDGE_VENV="${VENV_PATH}"
export OPENCLAW_BRIDGE_RUN_DIR="${RUN_DIR}"
export OPENCLAW_BRIDGE_SKILL="${SKILL_NAME}"
export OPENCLAW_BRIDGE_ARGS="${SKILL_ARGS}"
export OPENCLAW_BRIDGE_MODEL="${MODEL}"
export OPENCLAW_BRIDGE_ASYNC="${ASYNC_MODE}"

# 启动桥接进程
echo "Starting bridge: ${BRIDGE_SCRIPT} (via environment variables)"
"${BRIDGE_SCRIPT}" &
CLEANUP_PID=$!

# 更新状态为 running
write_state "${STATE_RUNNING}" "started"
echo "${PROTOCOL_RUNNING} PID: ${CLEANUP_PID}"

# 启动 Watchdog（第三层防御）
run_watchdog "${TIMEOUT}" "${CLEANUP_PID}" &
WATCHDOG_PID=$!

# 启动心跳发送
HEARTBEAT_PID=""
if [ "${HEARTBEAT}" -gt 0 ]; then
    (
        while true; do
            sleep "${HEARTBEAT}"
            send_heartbeat
        done
    ) &
    HEARTBEAT_PID=$!
fi

# 等待进程结束
wait ${CLEANUP_PID}
EXIT_CODE=$?

# 清理 Watchdog 和 Heartbeat
if [ -n "${WATCHDOG_PID}" ]; then
    kill "${WATCHDOG_PID}" 2>/dev/null || true
fi
if [ -n "${HEARTBEAT_PID}" ]; then
    kill "${HEARTBEAT_PID}" 2>/dev/null || true
fi

# 检查退出状态
if [ ${EXIT_CODE} -eq 0 ]; then
    write_state "${STATE_DONE}"
    echo "${PROTOCOL_DONE} Exit code: ${EXIT_CODE}"
else
    write_state "${STATE_ERROR}" "exit_code_${EXIT_CODE}"
    echo "${PROTOCOL_ERROR} Exit code: ${EXIT_CODE}"
fi

# 输出结果
echo ""
echo "=== Run Complete ==="
echo "Run Directory: ${RUN_DIR}"
echo "State: $(read_state | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"state\",\"unknown\"))' 2>/dev/null || echo "unknown")"

exit ${EXIT_CODE}
