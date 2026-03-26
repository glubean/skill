#!/bin/bash
set -e

# Install or upgrade the Glubean CLI globally.
# After this, the agent can run `glubean init` and `glubean config mcp` directly.

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

echo "{\"ok\":true,\"version\":\"$(glubean --version 2>/dev/null)\"}"
