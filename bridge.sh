#!/bin/bash
#
# OpenClaw Bridge - Venv 激活层
# 负责激活 Python 虚拟环境并调用 bridge.py
#

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认虚拟环境路径
DEFAULT_VENV="${SCRIPT_DIR}/.venv"

# 从环境变量读取参数（避免 shell 引号问题）
VENV_PATH="${OPENCLAW_BRIDGE_VENV:-$DEFAULT_VENV}"
RUN_DIR="${OPENCLAW_BRIDGE_RUN_DIR}"
SKILL_NAME="${OPENCLAW_BRIDGE_SKILL}"
SKILL_ARGS="${OPENCLAW_BRIDGE_ARGS}"
MODEL="${OPENCLAW_BRIDGE_MODEL:-sonnet}"
ASYNC_MODE="${OPENCLAW_BRIDGE_ASYNC:-false}"

# 检查虚拟环境
if [ -f "${VENV_PATH}/bin/activate" ]; then
    # 激活虚拟环境
    source "${VENV_PATH}/bin/activate"

    # 设置 PYTHONPATH
    export PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH}"

    # 执行 Python 桥接
    exec python3 "${SCRIPT_DIR}/bridge.py" \
        --run-dir="${RUN_DIR}" \
        --skill="${SKILL_NAME}" \
        --args="${SKILL_ARGS}" \
        --model="${MODEL}" \
        $([ "${ASYNC_MODE}" = "true" ] && echo "--async")
else
    # 没有虚拟环境，使用系统 Python
    export PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH}"
    exec python3 "${SCRIPT_DIR}/bridge.py" \
        --run-dir="${RUN_DIR}" \
        --skill="${SKILL_NAME}" \
        --args="${SKILL_ARGS}" \
        --model="${MODEL}" \
        $([ "${ASYNC_MODE}" = "true" ] && echo "--async")
fi
