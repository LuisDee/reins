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

That's it. The setup script will:

1. Check prerequisites (node, bun, uv, gemini CLI) and install missing ones via Homebrew
2. Merge MCP server configs into your existing `~/.gemini/settings.json` (or create one from scratch if none exists). Your existing servers and settings are preserved — reins only adds what's missing.
3. Pre-cache all MCP servers so first launch is fast
4. Install Playwright's Chromium for browser-based review
5. Copy agent definitions to `~/.gemini/agents/`
6. Run a smoke test to confirm everything loads

## Prerequisites

- **macOS** with [Homebrew](https://brew.sh) (Linux support planned)
- **Node.js** 18+ (`brew install node`)
- **Docker Desktop** 4.48+ (for Docker MCP — [download](https://www.docker.com/products/docker-desktop))
- **Gemini CLI** (`npm install -g @google/gemini-cli`)

The setup script will auto-install these if missing:
- [Bun](https://bun.sh) (for Hashline MCP server)
- [uv](https://docs.astral.sh/uv/) (for Serena LSP server)

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

The reviewer checks every spec objective and plan task against the actual code, runs tests, and optionally validates in a browser via Playwright. Returns a structured PASS/FAIL report.

## Manual Setup

If you prefer not to use `setup.sh`, or you're not on macOS:

1. **Clone the repo** as a Gemini extension:

   ```bash
   git clone https://github.com/LuisDee/reins.git ~/.gemini/extensions/reins
   ```

2. **Copy agents** to your user-level agents directory:

   ```bash
   mkdir -p ~/.gemini/agents
   cp ~/.gemini/extensions/reins/agents/*.md ~/.gemini/agents/
   ```

3. **Create `~/.gemini/settings.json`** using `settings.template.json` as a base. Replace the placeholder paths with absolute paths to your system's binaries:

   ```bash
   # Find your paths
   which npx    # e.g. /usr/local/bin/npx
   which bunx   # e.g. /usr/local/bin/bunx
   which uvx    # e.g. /usr/local/bin/uvx
   which docker # e.g. /usr/local/bin/docker
   ```

   Replace `__NPX__`, `__BUNX__`, `__UVX__`, and `__DOCKER__` in the template with these paths.

4. **Install Playwright browsers**:

   ```bash
   npx -y @playwright/mcp@0.0.68 -- --help  # caches the package
   npx playwright install chromium
   ```

## MCP Servers

| Server | Purpose | Runtime |
|--------|---------|---------|
| [Serena](https://github.com/oraios/serena) | LSP-based code navigation (find symbols, references, overview) | Python (uv) |
| [Hashline](https://github.com/nicobailey/mcp-hashline-edit-server) | Anchor-based file reading and editing (line-hash references) | Bun |
| [Context7](https://github.com/upstash/context7) | Library documentation lookup | Node |
| [Sequential Thinking](https://github.com/modelcontextprotocol/servers) | Structured reasoning before planning | Node |
| [Playwright](https://github.com/anthropics/mcp-playwright) | Browser automation for UI validation | Node |
| [Docker MCP](https://docs.docker.com/desktop/features/gordon-mcp/) | Container logs, inspection, health checks via MCP protocol | Docker Desktop 4.48+ |

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
  setup.sh             # One-command installer
```

## How It Works

Reins uses Gemini CLI's [extension system](https://github.com/google-gemini/gemini-cli) and [subagents](https://github.com/google-gemini/gemini-cli). Each agent is a Markdown file with YAML frontmatter that specifies its name, description, allowed tools, model, and temperature. The `GEMINI.md` file provides shared context to the main agent about the workflow and orchestration protocol.

Key design decisions:

- **Agents are read-only by default.** The investigator and reviewer cannot write files. The planner can only write to `.gemini/plans/current/`. This prevents accidental modifications.
- **The main agent orchestrates.** It creates plan directories, manages the `current` symlink, and persists subagent outputs returned via `complete_task`.
- **Tool routing is explicit.** Each agent's frontmatter lists exactly which MCP tools it can access, enforcing separation of concerns.

## License

MIT
