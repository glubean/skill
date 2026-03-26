#!/bin/bash
set -e

# Install or upgrade the Glubean CLI, then bootstrap the project.
# Usage: bash init.sh [--full] [--mcp]
#
# Without flags: install/upgrade CLI only
# --full        Also run `glubean init` (config/, .env, directories)
# --mcp         Also run `glubean config mcp`

FULL=false
MCP=false

for arg in "$@"; do
  case "$arg" in
    --full) FULL=true ;;
    --mcp)  MCP=true ;;
  esac
done

# --- Install or upgrade CLI ---

CURRENT=$(glubean --version 2>/dev/null || echo "none")
LATEST=$(npm view @glubean/cli version 2>/dev/null || echo "unknown")

if [ "$CURRENT" = "none" ]; then
  echo "Installing @glubean/cli@$LATEST..." >&2
  npm install -g @glubean/cli 2>&1 >&2
elif [ "$CURRENT" != "$LATEST" ]; then
  echo "Upgrading @glubean/cli $CURRENT → $LATEST..." >&2
  npm install -g @glubean/cli@latest 2>&1 >&2
else
  echo "@glubean/cli is up to date ($CURRENT)" >&2
fi

# --- Project init ---

if [ "$FULL" = true ]; then
  echo "Running glubean init..." >&2
  glubean init 2>&1 >&2
fi

# --- MCP config ---

if [ "$MCP" = true ]; then
  echo "Configuring MCP..." >&2
  glubean config mcp 2>&1 >&2
fi

# --- Result ---

echo "{\"ok\":true,\"cli\":\"$(glubean --version 2>/dev/null)\",\"init\":$FULL,\"mcp\":$MCP}"
