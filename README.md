# OpenClaw Bridge

A robust, enterprise-grade bridge system designed to connect **OpenClaw** (and other personal AI assistants) with agentic LLM interfaces like **Claude Code** and **Gemini CLI**.

This bridge provides a managed execution environment that ensures process isolation, security enforcement, and reliable state tracking for long-running AI tasks.

## Key Features

- **🚀 Managed Execution**: Wraps LLM SDKs/CLIs in a controlled environment with dedicated run directories.
- **📊 Real-time State Tracking**: Atomic updates to `state.json` track every phase: `starting`, `running`, `done`, `error`, and `killed`.
- **🛡️ Security Sandbox**: Built-in path validation and pattern matching to prevent unauthorized access to sensitive files (e.g., `.ssh`, `.env`, `/etc/passwd`).
- **⏲️ Robustness & Safety**:
  - **Watchdog Timer**: Automatically terminates hung processes after a configurable timeout.
  - **Heartbeat Mechanism**: Provides liveness signals for monitoring tools.
  - **Process Cleanup**: Ensures no "zombie" processes are left behind via multi-layer signal handling.
- **🔗 Tool Interception**: Specialized logic to intercept and relay user-confirmation tools (like `AskUserQuestion`) back to the parent agent.
- **📡 OpenClaw Native**: Built-in support for `openclaw agent --deliver` to notify the orchestrator of task completion or errors.
- **🔄 Sync/Async Modes**: Support for both blocking calls and background execution.

## Project Structure

- `bridge-runner.sh`: The entry point. Handles run directory creation, watchdog, and process management.
- `bridge.sh`: Handles Python virtual environment activation.
- `bridge.py`: The core logic layer. Manages SDK interaction, security checks, and protocol communication.
- `config.py`: Centralized configuration for models, timeouts, security rules, and paths.
- `runs/`: Organized storage for execution logs (`output.txt`) and metadata (`state.json`).

## Installation

### Prerequisites
- Python 3.10+
- [Optional] `claude-agent-sdk` (for the current Claude-based implementation)
- [Optional] `gemini-cli` (for upcoming Gemini support)

### Setup
1. Clone the repository to your OpenClaw workspace:
   ```bash
   git clone https://github.com/bono5137/clawbridge.git
   cd clawbridge
   ```
2. Create and initialize the virtual environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt  # Or pip install claude-agent-sdk
   ```

## Usage

### Basic Command
```bash
./bridge-runner.sh <skill_name> --args "<arguments>"
```

### Advanced Options
```bash
./bridge-runner.sh my-skill \
    --model sonnet \
    --timeout 600 \
    --async \
    --args "Refactor the authentication logic in src/auth.py"
```

## Integration with OpenClaw

OpenClaw agents can invoke this bridge as a "Shell Tool" or through a dedicated provider. The bridge communicates back to OpenClaw using:
1. **Exit Codes**: Standard Unix exit codes for success/failure.
2. **Protocol Tags**: Structured stdout markers like `[BRIDGE:RUNNING]` or `[BRIDGE:ERROR]`.
3. **Delivery Command**: Automatically executes `openclaw agent --deliver` upon completion.

## Roadmap
- [ ] Native Gemini CLI support with `stream-json` parsing.
- [ ] Visual dashboard for monitoring active runs.
- [ ] Enhanced telemetry for token usage and cost tracking.

## License
MIT
