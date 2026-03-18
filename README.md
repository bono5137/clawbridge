# OpenClaw Bridge

A robust, enterprise-grade bridge system designed to connect **OpenClaw** (and other personal AI assistants) with agentic LLM interfaces like **Claude Code** and **Gemini CLI**.

This bridge provides a managed execution environment that ensures process isolation, security enforcement, and reliable state tracking for long-running AI tasks.
[中文说明](https://github.com/git-tramp/clawbridge/blob/main/README-zh.md)

## Key Features

- **🚀 Managed Execution**: Wraps LLM SDKs/CLIs in a controlled environment with dedicated run directories.
- **🤖 Multi-Backend Support**: Seamlessly switch between **Claude Code** (via SDK) and **Gemini CLI** (via native binary).
- **📊 Real-time State Tracking**: Atomic updates to `state.json` track every phase: `starting`, `running`, `done`, `error`, and `killed`.
- **🛡️ Security Sandbox**: Built-in path validation and pattern matching to prevent unauthorized access to sensitive files (e.g., `.ssh`, `.env`, `/etc/passwd`).
- **⏲️ Robustness & Safety**:
  - **Watchdog Timer**: Automatically terminates hung processes after a configurable timeout.
  - **Heartbeat Mechanism**: Provides liveness signals for monitoring tools.
  - **Process Cleanup**: Ensures no "zombie" processes are left behind via multi-layer signal handling.
- **🔗 Tool Interception**: Specialized logic to intercept and relay user-confirmation tools (like `AskUserQuestion` and Gemini's `ask_user`) back to the parent agent.
- **📡 OpenClaw Native**: Built-in support for `openclaw agent --deliver` to notify the orchestrator of task completion or errors.
- **🔄 Sync/Async Modes**: Support for both blocking calls and background execution.

## Project Structure

- `bridge-runner.sh`: The entry point. Handles run directory creation, watchdog, and process management.
- `bridge.sh`: Handles Python virtual environment activation.
- `bridge.py`: The core logic layer. Manages SDK interaction, security checks, and protocol communication.
- `config.py`: Centralized configuration for models, backends, timeouts, security rules, and paths.
- `runs/`: Organized storage for execution logs (`output.txt`) and metadata (`state.json`).

## Installation

### Prerequisites
- Python 3.10+
- `claude-agent-sdk` (for Claude backend)
- `gemini-cli` (for Gemini backend)

### Setup
1. Clone the repository to your OpenClaw workspace:
   ```bash
   git clone https://github.com/git-tramp/clawbridge.git
   cd clawbridge
   ```
2. Create and initialize the virtual environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt  # Or pip install claude-agent-sdk
   ```

## Usage

### Basic Command (Claude - Default)
```bash
./bridge-runner.sh <skill_name> --args "<arguments>"
```

### Using Gemini CLI
```bash
./bridge-runner.sh <skill_name> --backend gemini --model auto-gemini-3 --args "<arguments>"
```

### Advanced Options
```bash
./bridge-runner.sh my-skill \
    --backend gemini \
    --model auto-gemini-3 \
    --timeout 600 \
    --async \
    --args "Refactor the authentication logic in src/auth.py"
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `<skill_name>` | Name of the skill to execute (required) | - |
| `--args "<text>"` | Arguments to pass to the skill | "" |
| `--model <model>` | Model to use (sonnet/opus/haiku for Claude, auto-gemini-3/gemini-2.0-flash-exp for Gemini) | sonnet |
| `--backend <backend>` | Backend to use: `claude` or `gemini` | claude |
| `--timeout <seconds>` | Execution timeout in seconds | 600 |
| `--heartbeat <seconds>` | Heartbeat interval in seconds | 30 |
| `--async` | Run in async mode (background) | false |
| `-h, --help` | Show help message | - |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENCLAW_ROOT` | OpenClaw root directory | `~/.openclaw` |
| `OPENCLAW_BRIDGE_DIR` | Bridge working directory | `./runs` |
| `OPENCLAW_SKILLS_DIR` | Skills directory | `${OPENCLAW_ROOT}/workspace/skills` |
| `OPENCLAW_VENV_PATH` | Python virtual environment path | `./.venv` |
| `OPENCLAW_AGENT_ID` | Agent ID for notifications | - |
| `OPENCLAW_NOTIFY_CMD` | Custom notification command | - |
| `BRIDGE_BACKEND` | Default backend (claude/gemini) | claude |
| `CLAUDE_MODEL` | Default Claude model | sonnet |
| `GEMINI_MODEL` | Default Gemini model | auto-gemini-3 |
| `GEMINI_PATH` | Path to Gemini CLI executable | gemini |
| `GEMINI_APPROVAL_MODE` | Gemini approval mode (default/auto_edit/yolo/plan) | yolo |
| `BRIDGE_EXECUTION_TIMEOUT` | Default execution timeout (seconds) | 600 |
| `BRIDGE_HEARTBEAT_INTERVAL` | Default heartbeat interval (seconds) | 30 |
| `BRIDGE_DEBUG` | Enable debug mode (true/false) | false |

## Integration with OpenClaw

OpenClaw agents can invoke this bridge as a "Shell Tool" or through a dedicated provider. The bridge communicates back to OpenClaw using:
1. **Exit Codes**: Standard Unix exit codes for success/failure.
2. **Protocol Tags**: Structured stdout markers like `[BRIDGE:RUNNING]` or `[BRIDGE:ERROR]`.
3. **Delivery Command**: Automatically executes `openclaw agent --deliver` upon completion.

## State File Format

The bridge creates a `state.json` file in each run directory with the following structure:

```json
{
  "state": "running",
  "skill": "my-skill",
  "args": "arguments",
  "model": "sonnet",
  "run_dir": "/path/to/runs/my-skill/run-20240318-143000",
  "timestamp": "2024-03-18T14:30:00Z",
  "pid": 12345,
  "started_at": "2024-03-18T14:30:00Z",
  "completed_at": "2024-03-18T14:35:00Z"
}
```

### State Values

| State | Description |
|-------|-------------|
| `starting` | Bridge is initializing |
| `running` | Skill is executing |
| `done` | Skill completed successfully |
| `error` | An error occurred |
| `killed` | Process was terminated |

## Skills Directory Structure

Skills must be organized in the skills directory with the following structure:

```
skills/
└── <skill_name>/
    ├── SKILL.md          # Required: Skill definition and instructions
    ├── README.md         # Optional: Skill documentation
    └── (other files)     # Optional: Any additional resources
```

### SKILL.md Format

The `SKILL.md` file should contain:

```markdown
# Skill Name

## Description
Brief description of what this skill does.

## Usage
How to use this skill.

## Parameters
- param1: Description
- param2: Description
```

### Security Rules

The bridge enforces security rules to prevent unauthorized access:

- **Forbidden Directories**: `/.ssh`, `/.aws`, `/.gnupg`, `/.token`, `/private`, `/etc/passwd`, `/etc/shadow`
- **Forbidden Patterns**: `**/.ssh/**`, `**/.aws/**`, `**/.gnupg/**`, `**/credentials*`, `**/password*`, `**/secret*`, `**/id_rsa*`

The `SKILL.md` file must exist and cannot be empty.

## Roadmap
- [x] Native Gemini CLI support with `stream-json` parsing.
- [ ] Visual dashboard for monitoring active runs.
- [ ] Enhanced telemetry for token usage and cost tracking.

## License
MIT
