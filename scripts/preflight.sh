#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_TAB="${RP_TAB:-T1}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"

usage() {
  cat <<'USAGE'
Usage:
  preflight.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME]

Checks:
  - Repo Prompt running + MCP enabled
  - rp-cli available
  - Window routing validity (no -w required for single-window setups)
  - Tab exists in the targeted window

Environment defaults:
  RP_WINDOW (optional), RP_TAB (default: T1), RP_WORKSPACE (default: GitHub)
USAGE
}

if ! command -v rp-cli >/dev/null 2>&1; then
  echo "rp-cli not found in PATH. Install via Repo Prompt → Settings → MCP Server → Install CLI to PATH." >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2;;
    -t|--tab) TAB="$2"; shift 2;;
    --workspace) WORKSPACE="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

# Defaults
if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

# Check windows first (connectivity + routing constraints)
WIN_OUT=$(rp-cli -e 'windows' 2>&1 || true)
if [[ -z "$WIN_OUT" ]]; then
  echo "Repo Prompt not running or MCP Server disabled." >&2
  exit 1
fi

WIN_COUNT=$(printf '%s\n' "$WIN_OUT" | sed -nE 's/.*Count[^0-9]*([0-9]+).*/\1/p' | head -n1)
WINDOW_IDS=$(printf '%s\n' "$WIN_OUT" | sed -nE 's/.*Window `?([0-9]+)`?.*/\1/p')

if [[ -z "$WIN_COUNT" ]]; then
  if [[ -n "$WINDOW_IDS" ]]; then
    WIN_COUNT=$(printf '%s\n' "$WINDOW_IDS" | sed '/^$/d' | wc -l | tr -d ' ')
  else
    WIN_COUNT=1
  fi
fi

if [[ "$WIN_COUNT" -gt 1 && -z "$WINDOW" ]]; then
  echo "Multiple Repo Prompt windows detected. Set RP_WINDOW or pass -w." >&2
  echo "$WIN_OUT" >&2
  exit 2
fi

if [[ -n "$WINDOW" && -n "$WINDOW_IDS" ]]; then
  if ! printf '%s\n' "$WINDOW_IDS" | grep -qx "$WINDOW"; then
    echo "Window '$WINDOW' not found." >&2
    echo "$WIN_OUT" >&2
    exit 2
  fi
fi

# Tab check in the targeted window
if [[ -n "$WINDOW" ]]; then
  if ! TABS_OUT=$(rp-cli -w "$WINDOW" -e 'tabs' 2>&1); then
    echo "Repo Prompt not running or MCP Server disabled." >&2
    echo "$TABS_OUT" >&2
    exit 1
  fi
else
  if ! TABS_OUT=$(rp-cli -e 'tabs' 2>&1); then
    echo "Repo Prompt not running or MCP Server disabled." >&2
    echo "$TABS_OUT" >&2
    exit 1
  fi
fi

if ! echo "$TABS_OUT" | grep -q "• $TAB"; then
  echo "Tab '$TAB' not found. Available tabs:" >&2
  echo "$TABS_OUT" >&2
  exit 3
fi

echo "Repo Prompt OK. window=${WINDOW:-single} tab=$TAB workspace=$WORKSPACE" >&2
