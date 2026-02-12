#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
SELECT_SET=""
TASK=""
OUT=""

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"
DEFAULT_TAB="${RP_TAB:-T1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  plan-export.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] --select-set PATHS --task TEXT --out FILE

Notes:
  - PATHS is a comma-separated list (e.g. repo/,src/,README.md)
  - Runs rpflow autopilot (preflight + builder plan + prompt export)
  - Includes retry-on-timeout and fallback export by default
  - Defaults: RP_WINDOW (optional), RP_TAB (or T1), RP_WORKSPACE (or GitHub)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --select-set) SELECT_SET="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

if [[ -z "$WORKSPACE" || -z "$SELECT_SET" || -z "$TASK" || -z "$OUT" ]]; then
  echo "Missing required args" >&2
  usage
  exit 2
fi

ARGS=(autopilot --select-set "$SELECT_SET" --task "$TASK" --out "$OUT" --retry-on-timeout --fallback-export-on-timeout)
if [[ -n "$WINDOW" ]]; then ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then ARGS+=(--workspace "$WORKSPACE"); fi

"$SCRIPT_DIR/rpflow.sh" "${ARGS[@]}"
echo "Plan + prompt exported to: $OUT" >&2
