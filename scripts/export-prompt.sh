#!/usr/bin/env bash
set -euo pipefail

# Export an LLM-ready prompt/context file from Repo Prompt via rp-cli.
#
# Usage:
#   export-prompt.sh -w 1 -t MyTab --workspace MyProject --select-set src/ --out ~/context.md

WINDOW=""
TAB=""
WORKSPACE=""
SELECT_SET=""
OUT=""

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"
DEFAULT_TAB="${RP_TAB:-T1}"

usage() {
  cat <<'USAGE'
Usage:
  export-prompt.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] --select-set PATHS --out FILE

Notes:
  - PATHS can be a comma-separated list (e.g. src/,lib/)
  - Requires Repo Prompt running + MCP Server enabled + rp-cli on PATH
  - Defaults: RP_WINDOW (optional), RP_TAB (or T1), RP_WORKSPACE (or GitHub)
USAGE
}

if ! command -v rp-cli >/dev/null 2>&1; then
  echo "rp-cli not found in PATH." >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2;;
    -t|--tab) TAB="$2"; shift 2;;
    --workspace) WORKSPACE="$2"; shift 2;;
    --select-set) SELECT_SET="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

# Defaults
if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

if [[ -z "$WORKSPACE" || -z "$SELECT_SET" || -z "$OUT" ]]; then
  echo "Missing required args" >&2
  usage
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/preflight.sh" ${WINDOW:+-w "$WINDOW"} ${TAB:+-t "$TAB"} --workspace "$WORKSPACE" >/dev/null

IFS=',' read -r -a PATHS <<< "$SELECT_SET"

ARGS=()
if [[ -n "$WINDOW" ]]; then ARGS+=("-w" "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=("-t" "$TAB"); fi

# Build an exec chain.
CMD="workspace switch \"$WORKSPACE\" && select clear"
for p in "${PATHS[@]}"; do
  CMD+=" && select add \"$p\""
done
CMD+=" && prompt export \"$OUT\""

rp-cli "${ARGS[@]}" -e "$CMD"
echo "Exported to: $OUT" >&2
