#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Documents/github"
WORKSPACE_NAME="GitHub"

if ! command -v rp-cli >/dev/null 2>&1; then
  echo "rp-cli not found in PATH. Install via Repo Prompt → Settings → MCP Server → Install CLI to PATH." >&2
  exit 1
fi

mkdir -p "$ROOT"

# Create workspace if missing, otherwise just switch to it.
if rp-cli -e 'workspace list' | grep -q "• ${WORKSPACE_NAME}"; then
  set +e
  OUT=$(rp-cli -e "workspace switch \"$WORKSPACE_NAME\"" 2>&1)
  RC=$?
  set -e
  if [[ $RC -ne 0 ]] && ! echo "$OUT" | grep -qi 'already on workspace'; then
    echo "$OUT" >&2
    exit $RC
  fi
else
  rp-cli -e "workspace create \"$WORKSPACE_NAME\" --folder-path \"$ROOT\" --switch"
fi

# Show status (useful for debugging automation state)
rp-cli -e 'tabs'
rp-cli -e 'context --include tokens,tree,selection,prompt --path-display relative'

echo "Bootstrapped Repo Prompt workspace '$WORKSPACE_NAME' at: $ROOT" >&2
