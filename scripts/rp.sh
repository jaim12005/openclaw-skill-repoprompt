#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
CMD=""

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"
DEFAULT_TAB="${RP_TAB:-T1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  rp.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] -e '...'

Notes:
  - rpflow-first wrapper around `rpflow exec`
  - If -t/--tab is omitted, defaults to RP_TAB (or T1)
  - If -w/--window is omitted, defaults to RP_WINDOW if set
  - Workspace defaults to RP_WORKSPACE (or GitHub)

Examples:
  rp.sh -e 'windows'
  rp.sh --workspace GitHub -e 'tree --folders'
  rp.sh -w 1 -t T1 --workspace MyRepo -e 'select set src/ && builder "Find auth code" --type plan'
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    -e|--exec) CMD="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$CMD" ]]; then
  echo "Missing -e/--exec" >&2
  usage
  exit 2
fi

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

ARGS=(exec -e "$CMD")
if [[ -n "$WINDOW" ]]; then ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then ARGS+=(--workspace "$WORKSPACE"); fi

exec "$SCRIPT_DIR/rpflow.sh" "${ARGS[@]}"
