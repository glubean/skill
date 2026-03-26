#!/bin/bash
set -e

# Install or upgrade the Glubean CLI globally.
# After this, the agent runs `glubean init` and `glubean config mcp` directly.

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat >&2 <<'HELP'
Usage: bash scripts/init.sh

Install or upgrade @glubean/cli globally. Idempotent — safe to run repeatedly.

Exit codes:
  0  CLI installed or already up to date
  1  npm not found or install failed

Output (stdout): JSON with ok, version, and action taken.
Diagnostics (stderr): progress messages.

After running this script, the agent should run interactively:
  glubean init          # initialize project (config/, .env, directories)
  glubean config mcp    # configure MCP tools (user selects agent)
HELP
  exit 0
fi

if ! command -v npm &>/dev/null; then
  echo '{"ok":false,"error":"npm not found. Install Node.js 18+ first."}'
  exit 1
fi

CURRENT=$(glubean --version 2>/dev/null || echo "")
LATEST=$(npm view @glubean/cli version 2>/dev/null || echo "")

if [ -z "$LATEST" ]; then
  echo '{"ok":false,"error":"Could not reach npm registry."}'
  exit 1
fi

if [ -z "$CURRENT" ]; then
  echo "Installing @glubean/cli@$LATEST..." >&2
  npm install -g @glubean/cli 2>&1 >&2
  echo "{\"ok\":true,\"version\":\"$LATEST\",\"action\":\"installed\"}"
elif [ "$CURRENT" != "$LATEST" ]; then
  echo "Upgrading @glubean/cli $CURRENT → $LATEST..." >&2
  npm install -g @glubean/cli@latest 2>&1 >&2
  echo "{\"ok\":true,\"version\":\"$LATEST\",\"action\":\"upgraded\",\"from\":\"$CURRENT\"}"
else
  echo "@glubean/cli is up to date." >&2
  echo "{\"ok\":true,\"version\":\"$CURRENT\",\"action\":\"none\"}"
fi
