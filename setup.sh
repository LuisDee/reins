#!/usr/bin/env bash
set -euo pipefail

# Reins extension setup — installs all prerequisites and validates the environment.
#
# Usage:
#   git clone https://github.com/LuisDee/reins.git ~/.gemini/extensions/reins
#   cd ~/.gemini/extensions/reins
#   bash setup.sh

# ─── Pinned versions ──────────────────────────────────────────────────────────
SERENA_COMMIT="dcbf08520d9b6bccafc9f994284ea2be22458c56"
HASHLINE_VERSION="0.2.0"
SEQTHINK_VERSION="2025.12.18"
CONTEXT7_VERSION="2.1.1"
PLAYWRIGHT_VERSION="0.0.68"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
step() { echo -e "\n${BLUE}${BOLD}$1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${BOLD}Reins — Gemini CLI Extension Installer${NC}"
echo ""

# ─── Link extension if cloned outside ~/.gemini/extensions ───────────────────
step "[1/7] Linking extension"

EXTENSION_DIR="$HOME/.gemini/extensions/reins"
if [ "$SCRIPT_DIR" = "$EXTENSION_DIR" ]; then
  ok "already in ~/.gemini/extensions/reins"
elif [ -L "$EXTENSION_DIR" ] && [ "$(readlink "$EXTENSION_DIR")" = "$SCRIPT_DIR" ]; then
  ok "symlink already exists"
else
  mkdir -p "$HOME/.gemini/extensions"
  if [ -d "$EXTENSION_DIR" ] && [ ! -L "$EXTENSION_DIR" ]; then
    warn "~/.gemini/extensions/reins already exists (not a symlink)"
    warn "backing up to ~/.gemini/extensions/reins.bak"
    mv "$EXTENSION_DIR" "${EXTENSION_DIR}.bak"
  fi
  ln -sfn "$SCRIPT_DIR" "$EXTENSION_DIR"
  ok "linked $SCRIPT_DIR -> ~/.gemini/extensions/reins"
fi

# ─── Check prerequisites ─────────────────────────────────────────────────────
step "[2/7] Checking prerequisites"

errors=0

if command -v node &>/dev/null; then
  ok "node $(node --version)"
else
  fail "node not found — install via: brew install node"
  ((errors++))
fi

if command -v npx &>/dev/null; then
  ok "npx $(npx --version)"
else
  fail "npx not found — comes with node"
  ((errors++))
fi

if command -v bun &>/dev/null; then
  ok "bun $(bun --version)"
else
  warn "bun not found — installing via brew..."
  brew install oven-sh/bun/bun
  ok "bun $(bun --version)"
fi

if command -v uv &>/dev/null; then
  ok "uv $(uv --version)"
else
  warn "uv not found — installing via brew..."
  brew install uv
  ok "uv $(uv --version)"
fi

if command -v gemini &>/dev/null; then
  ok "gemini CLI $(gemini --version 2>&1)"
else
  fail "gemini CLI not found — install via: npm install -g @google/gemini-cli"
  ((errors++))
fi

if [ "$errors" -gt 0 ]; then
  fail "$errors prerequisite(s) missing. Fix and re-run."
  exit 1
fi

# ─── Generate settings.json ─────────────────────────────────────────────────
step "[3/7] Configuring settings.json"

SETTINGS="$HOME/.gemini/settings.json"

if [ -f "$SETTINGS" ]; then
  ok "~/.gemini/settings.json already exists — validating"

  if python3 -m json.tool "$SETTINGS" &>/dev/null; then
    ok "valid JSON"
  else
    fail "invalid JSON in settings.json — fix manually or delete to regenerate"
    exit 1
  fi

  # Check required keys
  valid=true
  if ! python3 -c "import json; d=json.load(open('$SETTINGS')); assert d.get('subagents')" 2>/dev/null; then
    fail "\"subagents\": true not set"
    valid=false
  fi
  if ! python3 -c "import json; d=json.load(open('$SETTINGS')); assert d.get('experimental',{}).get('enableAgents')" 2>/dev/null; then
    fail "\"experimental.enableAgents\": true not set"
    valid=false
  fi

  SERVERS=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(' '.join(d.get('mcpServers',{}).keys()))")
  for srv in lsp hashline context7 sequential-thinking playwright; do
    if echo "$SERVERS" | grep -qw "$srv"; then
      ok "MCP server: $srv"
    else
      fail "MCP server '$srv' missing from settings.json"
      valid=false
    fi
  done

  if [ "$valid" = false ]; then
    warn "settings.json exists but has issues — see errors above"
    warn "delete ~/.gemini/settings.json and re-run setup.sh to regenerate"
  fi
else
  ok "generating ~/.gemini/settings.json from template"

  NPX_PATH="$(command -v npx)"
  BUNX_PATH="$(command -v bunx)"
  UVX_PATH="$(command -v uvx)"

  sed \
    -e "s|__NPX__|${NPX_PATH}|g" \
    -e "s|__BUNX__|${BUNX_PATH}|g" \
    -e "s|__UVX__|${UVX_PATH}|g" \
    "${SCRIPT_DIR}/settings.template.json" > "$SETTINGS"

  ok "wrote ~/.gemini/settings.json"
  ok "  npx  = ${NPX_PATH}"
  ok "  bunx = ${BUNX_PATH}"
  ok "  uvx  = ${UVX_PATH}"
fi

# ─── Pre-cache MCP servers ───────────────────────────────────────────────────
step "[4/7] Pre-caching MCP servers"

echo -n "  serena@${SERENA_COMMIT:0:8}... "
uvx --from "git+https://github.com/oraios/serena@${SERENA_COMMIT}" serena --help &>/dev/null && ok "cached" || warn "download may happen on first gemini launch"

echo -n "  mcp-hashline-edit-server@${HASHLINE_VERSION}... "
bunx mcp-hashline-edit-server@${HASHLINE_VERSION} --version &>/dev/null 2>&1 && ok "cached" || ok "will cache on first use"

echo -n "  @modelcontextprotocol/server-sequential-thinking@${SEQTHINK_VERSION}... "
npx -y @modelcontextprotocol/server-sequential-thinking@${SEQTHINK_VERSION} --help &>/dev/null 2>&1 && ok "cached" || ok "will cache on first use"

echo -n "  @upstash/context7-mcp@${CONTEXT7_VERSION}... "
npx -y @upstash/context7-mcp@${CONTEXT7_VERSION} --help &>/dev/null 2>&1 && ok "cached" || ok "will cache on first use"

echo -n "  @playwright/mcp@${PLAYWRIGHT_VERSION}... "
npx -y @playwright/mcp@${PLAYWRIGHT_VERSION} --help &>/dev/null 2>&1 && ok "cached" || ok "will cache on first use"

# ─── Install Playwright browsers ─────────────────────────────────────────────
step "[5/7] Playwright browsers"

if npx -y @playwright/mcp@${PLAYWRIGHT_VERSION} --help 2>&1 | grep -q "version"; then
  ok "chromium available"
else
  warn "installing chromium..."
  npx playwright install chromium
fi

# ─── Copy agents ──────────────────────────────────────────────────────────────
step "[6/7] Installing agents"

mkdir -p ~/.gemini/agents

for agent in investigator planner reviewer; do
  if [ -f "${SCRIPT_DIR}/agents/${agent}.md" ]; then
    cp "${SCRIPT_DIR}/agents/${agent}.md" "$HOME/.gemini/agents/${agent}.md"
    ok "${agent}"
  else
    fail "${agent}.md not found in extension"
  fi
done

# ─── Final smoke test ────────────────────────────────────────────────────────
step "[7/7] Smoke test"

echo "  launching gemini CLI (this takes ~15s)..."
TOOLS=$(gemini --allowed-mcp-server-names hashline,context7,sequential-thinking,playwright -p "list every tool name, one per line, just the function name" -o text 2>/dev/null) || true

smoke_ok=true
for agent in investigator planner reviewer; do
  if echo "$TOOLS" | grep -qw "$agent"; then
    ok "agent loaded: $agent"
  else
    fail "agent NOT loaded: $agent"
    smoke_ok=false
  fi
done

for tool in hashline__read_file resolve-library-id sequentialthinking browser_navigate; do
  if echo "$TOOLS" | grep -qw "$tool"; then
    ok "MCP tool: $tool"
  else
    fail "MCP tool missing: $tool"
    smoke_ok=false
  fi
done

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
if [ "$smoke_ok" = true ]; then
  echo -e "${GREEN}${BOLD}Setup complete!${NC}"
else
  echo -e "${YELLOW}${BOLD}Setup complete with warnings.${NC} Check the errors above."
fi
echo ""
echo "  Run 'gemini' in any project and try:"
echo ""
echo "    @investigator trace why /api/login returns 401"
echo "    @planner plan a fix based on the investigation"
echo "    @reviewer review the changes against the plan"
echo ""
