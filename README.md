# Reins

A [Gemini CLI](https://github.com/google-gemini/gemini-cli) extension that adds three specialised subagents for structured software development: **investigate**, **plan**, **review**.

Instead of one agent doing everything in a single conversation, Reins splits the work into focused phases with clear handoffs, each backed by purpose-built MCP tool sets.

## What You Get

| Agent | Role | Key Tools |
|-------|------|-----------|
| **investigator** | Deep debugging and root cause analysis. Read-only. | Serena (LSP), Hashline, Docker MCP, grep |
| **planner** | TDD implementation plans with spec + plan files. | Serena, Context7 (docs), Sequential Thinking |
| **reviewer** | Reviews implementation against spec/plan. Validates in browser and containers. | Serena, Hashline, Playwright (browser), Docker MCP |

The main Gemini agent orchestrates the workflow: it creates numbered plan directories, delegates to subagents, and persists their outputs. A `current` symlink always points to the active plan so agents never need hardcoded paths.

```
.gemini/plans/
  current -> 2          # symlink to active plan
  1/
    investigation.md
    spec.md
    plan.md
    review.md
  2/ ...
```

## Quick Start

```bash
git clone https://github.com/LuisDee/reins.git ~/.gemini/extensions/reins
cd ~/.gemini/extensions/reins
bash setup.sh
```

That's it. The setup script detects your OS (macOS or Linux) and will:

1. Check and install prerequisites (node, bun, uv, Docker MCP plugin)
2. Merge MCP server configs into your existing `~/.gemini/settings.json` — your existing servers and settings are preserved, reins only adds what's missing
3. Pre-cache all MCP servers so first launch is fast
4. Install Playwright's Chromium (including system deps on Linux)
5. Copy agent definitions to `~/.gemini/agents/`
6. Run a smoke test to confirm everything loads

## Prerequisites

- **macOS** (Homebrew) or **Linux** (Ubuntu/Debian)
- **Node.js** 18+ (macOS: `brew install node`, Linux: `sudo apt install nodejs npm`)
- **Docker Engine** (macOS: [Docker Desktop](https://www.docker.com/products/docker-desktop), Linux: `sudo apt install docker.io`)
- **Gemini CLI** (`npm install -g @google/gemini-cli`)

The setup script will auto-install these if missing:
- [Bun](https://bun.sh) — for Hashline MCP server
- [uv](https://docs.astral.sh/uv/) — for Serena LSP server
- [Docker MCP plugin](https://github.com/docker/mcp-gateway) — downloaded from GitHub releases, works with Docker Engine alone (no Docker Desktop required on Linux)

## Usage

Launch Gemini CLI in any project and use the agents:

### Investigate a bug

```
> @investigator The /api/upload endpoint returns 500 when files are > 10MB.
>   Here's the error log: [paste log]
```

The investigator traces the code path, identifies root cause, and returns a structured report. The main agent saves it to `.gemini/plans/current/investigation.md`.

### Plan a fix

```
> @planner Fix the upload size handling based on the investigation
```

The planner reads the investigation, researches best practices via Context7, reasons through the approach with Sequential Thinking, and writes `spec.md` + `plan.md`.

### Implement (you + main agent)

The main agent executes the plan step by step, using Hashline for precise file edits and Serena for code navigation. You approve each change.

### Review

```
> @reviewer Review the upload fix against the spec and plan
```

The reviewer checks every spec objective and plan task against the actual code and optionally validates in a browser via Playwright or inspects containers via Docker MCP. Returns a structured PASS/FAIL report.

## Headless Linux / Coder Workspaces

Reins works on headless Linux servers and [Coder](https://coder.com/) workspaces:

- **Playwright** runs Chromium in headless mode by default — no X11 or display server needed. On Linux the setup script auto-installs the required system libraries (`libnss3`, `libatk-bridge2.0-0`, etc.). If you hit `SIGTRAP` crashes in containerised environments, set `CHROMIUM_FLAGS=--no-sandbox` or run with `--cap-add=SYS_ADMIN`.

- **Docker MCP** works with Docker Engine only — no Docker Desktop required. The setup script downloads the [pre-built plugin binary](https://github.com/docker/mcp-gateway/releases) and installs it to `~/.docker/cli-plugins/`. On Linux, it sets `DOCKER_MCP_IN_CONTAINER=1` to bypass Desktop feature checks. Add this to your shell profile for persistence:

  ```bash
  export DOCKER_MCP_IN_CONTAINER=1
  ```

- **Coder port forwarding** — if the reviewer needs to validate a web UI, Playwright connects via `localhost:<port>`. Coder's native port forwarding makes services accessible without extra config.

## Manual Setup

If you prefer not to use `setup.sh`:

1. **Clone the repo** as a Gemini extension:

   ```bash
   git clone https://github.com/LuisDee/reins.git ~/.gemini/extensions/reins
   ```

2. **Copy agents** to your user-level agents directory:

   ```bash
   mkdir -p ~/.gemini/agents
   cp ~/.gemini/extensions/reins/agents/*.md ~/.gemini/agents/
   ```

3. **Install the Docker MCP plugin**:

   ```bash
   # macOS (if using Docker Desktop 4.48+, you already have it)
   # Linux — download the binary:
   curl -fsSL https://github.com/docker/mcp-gateway/releases/download/v0.40.0/docker-mcp-linux-amd64.tar.gz | tar xz
   mkdir -p ~/.docker/cli-plugins
   mv docker-mcp ~/.docker/cli-plugins/docker-mcp
   chmod +x ~/.docker/cli-plugins/docker-mcp

   # Linux only — bypass Desktop check:
   export DOCKER_MCP_IN_CONTAINER=1
   ```

4. **Create `~/.gemini/settings.json`** using `settings.template.json` as a base. Replace the placeholder paths with absolute paths to your system's binaries:

   ```bash
   # Find your paths
   which npx    # e.g. /usr/local/bin/npx
   which bunx   # e.g. /usr/local/bin/bunx or ~/.bun/bin/bunx
   which uvx    # e.g. /usr/local/bin/uvx or ~/.local/bin/uvx
   which docker # e.g. /usr/local/bin/docker
   ```

   Replace `__NPX__`, `__BUNX__`, `__UVX__`, and `__DOCKER__` in the template with these paths.

5. **Install Playwright browsers** (and system deps on Linux):

   ```bash
   # Linux only — system dependencies:
   sudo npx playwright install-deps chromium

   # All platforms:
   npx playwright install chromium
   ```

## MCP Servers

| Server | Purpose | Runtime |
|--------|---------|---------|
| [Serena](https://github.com/oraios/serena) | LSP-based code navigation (find symbols, references, overview) | Python (uv) |
| [Hashline](https://github.com/nicobailey/mcp-hashline-edit-server) | Anchor-based file reading and editing (line-hash references) | Bun |
| [Context7](https://github.com/upstash/context7) | Library documentation lookup | Node |
| [Sequential Thinking](https://github.com/modelcontextprotocol/servers) | Structured reasoning before planning | Node |
| [Playwright](https://github.com/microsoft/playwright-mcp) | Browser automation for UI validation | Node |
| [Docker MCP](https://github.com/docker/mcp-gateway) | Container logs, inspection, health checks via MCP protocol | Docker Engine |

## Project Structure

```
reins/
  agents/
    investigator.md    # Deep investigation agent
    planner.md         # TDD planning agent
    reviewer.md        # Code review agent
  GEMINI.md            # Extension context (workflow + orchestration protocol)
  gemini-extension.json
  settings.template.json
  setup.sh             # One-command installer (macOS + Linux)
```

## How It Works

Reins uses Gemini CLI's [extension system](https://github.com/google-gemini/gemini-cli) and [subagents](https://github.com/google-gemini/gemini-cli). Each agent is a Markdown file with YAML frontmatter that specifies its name, description, allowed tools, model, and temperature. The `GEMINI.md` file provides shared context to the main agent about the workflow and orchestration protocol.

Key design decisions:

- **Agents are read-only by default.** The investigator and reviewer cannot write files or run shell commands. The planner can only write to `.gemini/plans/current/`. This prevents accidental modifications.
- **No shell access.** Container interaction goes through Docker MCP's structured protocol, not `run_shell_command`. Browser validation goes through Playwright MCP. This gives agents the capabilities they need without shell escape risk.
- **The main agent orchestrates.** It creates plan directories, manages the `current` symlink, and persists subagent outputs returned via `complete_task`.
- **Tool routing is explicit.** Each agent's frontmatter lists exactly which MCP tools it can access, enforcing separation of concerns.

## Uninstall

```bash
# Remove agents
rm ~/.gemini/agents/{investigator,planner,reviewer}.md

# Remove extension
rm -rf ~/.gemini/extensions/reins

# Remove Docker MCP plugin (optional)
rm ~/.docker/cli-plugins/docker-mcp

# To remove reins MCP servers from settings.json, edit the file manually
# and remove the lsp, hashline, context7, sequential-thinking, playwright,
# and docker entries from mcpServers (keep any servers you added yourself).
```

## License

MIT
