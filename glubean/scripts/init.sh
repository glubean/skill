#!/bin/bash
set -e

# Glubean project bootstrap — from zero to runnable in one script.
# Usage: bash init.sh [--scratch | --full] [--mcp] [--client <name>]
#
# --scratch          Install SDK only, skip glubean init (default)
# --full             Run glubean init (config/, .env, directory structure)
# --mcp              Configure MCP tools for the specified client
# --client <name>    Agent client name (claude-code, cursor, codex, windsurf, etc.)

MODE="scratch"
MCP=false
CLIENT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --full)    MODE="full"; shift ;;
    --scratch) MODE="scratch"; shift ;;
    --mcp)     MCP=true; shift ;;
    --client)  CLIENT="$2"; shift 2 ;;
    *)         shift ;;
  esac
done

# --- Prereqs ---

echo "Checking prerequisites..." >&2

if ! command -v node &>/dev/null; then
  echo '{"ok":false,"error":"Node.js not found. Install Node.js 18+ first."}'
  exit 1
fi

NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])")
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "{\"ok\":false,\"error\":\"Node.js $NODE_MAJOR found, but 18+ required.\"}"
  exit 1
fi

if [ ! -f "package.json" ]; then
  echo "No package.json found, creating one..." >&2
  npm init -y --silent >/dev/null 2>&1
fi

# --- Install SDK + runner ---

echo "Installing @glubean/sdk and @glubean/runner..." >&2

if command -v pnpm &>/dev/null; then
  pnpm add -D @glubean/sdk @glubean/runner 2>&1 >&2
elif command -v npm &>/dev/null; then
  npm install -D @glubean/sdk @glubean/runner 2>&1 >&2
else
  echo '{"ok":false,"error":"No package manager found (npm or pnpm)."}'
  exit 1
fi

# --- Full init (optional) ---

if [ "$MODE" = "full" ]; then
  echo "Running glubean init..." >&2
  npx glubean init 2>&1 >&2
fi

# --- MCP install (optional) ---

if [ "$MCP" = true ]; then
  if [ -z "$CLIENT" ]; then
    echo '{"ok":false,"error":"--mcp requires --client <name> (claude-code, cursor, codex, windsurf, etc.)"}'
    exit 1
  fi
  echo "Installing MCP server for $CLIENT..." >&2
  npx -y install-mcp @glubean/mcp --client "$CLIENT" -y --oauth no 2>&1 >&2
fi

# --- JSON result ---

RESULT="{\"ok\":true,\"mode\":\"$MODE\",\"mcp\":$MCP"

if [ -n "$CLIENT" ]; then
  RESULT="$RESULT,\"client\":\"$CLIENT\""
fi

if [ "$MODE" = "full" ]; then
  RESULT="$RESULT,\"created\":[\"config/\",\".env\",\".env.secrets\",\"explore/\",\"tests/\"]"
fi

RESULT="$RESULT,\"next\":\"Write your first test in explore/\"}"

echo "$RESULT"
