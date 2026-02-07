#!/usr/bin/env bash
set -euo pipefail

# Export an LLM-ready prompt/context file from Repo Prompt via rpflow.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  export-prompt.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] --select-set PATHS --out FILE

Notes:
  - PATHS can be a comma-separated list (e.g. src/,lib/)
  - Requires Repo Prompt running + MCP Server enabled + rpflow repo available
  - Defaults: RP_WINDOW (optional), RP_TAB (or T1), RP_WORKSPACE (or GitHub)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --select-set) SELECT_SET="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

if [[ -z "$WORKSPACE" || -z "$SELECT_SET" || -z "$OUT" ]]; then
  echo "Missing required args" >&2
  usage
  exit 2
fi

bash "$SCRIPT_DIR/preflight.sh" ${WINDOW:+-w "$WINDOW"} ${TAB:+-t "$TAB"} --workspace "$WORKSPACE" >/dev/null

ARGS=(export --select-set "$SELECT_SET" --out "$OUT")
if [[ -n "$WINDOW" ]]; then ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then ARGS+=(--workspace "$WORKSPACE"); fi

"$SCRIPT_DIR/rpflow.sh" "${ARGS[@]}"
echo "Exported to: $OUT" >&2
