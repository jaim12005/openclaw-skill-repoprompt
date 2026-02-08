#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_TAB="${RP_TAB:-T1}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  preflight.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME]

Checks:
  - rpflow available (via scripts/rpflow.sh)
  - Repo Prompt routing health (tabs/context/tools-schema) via rpflow smoke

Behavior:
  - If no window is provided, preflight probes windows via rpflow exec -e 'windows'
  - If exactly one window is found, it is auto-selected
  - If multiple windows are found, exits with guidance to set -w / RP_WINDOW

Environment defaults:
  RP_WINDOW (optional), RP_TAB (default: T1), RP_WORKSPACE (default: GitHub)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

auto_select_window_if_needed() {
  if [[ -n "$WINDOW" ]]; then
    return 0
  fi

  local windows_out
  if ! windows_out="$($SCRIPT_DIR/rpflow.sh exec --profile fast -e 'windows' 2>&1)"; then
    # Fall through; smoke will emit the actionable error if routing is broken.
    return 0
  fi

  local window_ids
  window_ids="$(printf '%s\n' "$windows_out" | sed -nE 's/.*Window `([0-9]+)`.*/\1/p' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

  local count
  count="$(printf '%s\n' "$window_ids" | awk '{print NF}')"

  if [[ "$count" -eq 1 ]]; then
    WINDOW="$window_ids"
    echo "Repo Prompt preflight: auto-selected window=$WINDOW" >&2
    return 0
  fi

  if [[ "$count" -gt 1 ]]; then
    echo "Repo Prompt preflight requires explicit window selection." >&2
    echo "Detected windows: $window_ids" >&2
    echo "Next step: rerun with -w <window_id> or export RP_WINDOW=<window_id>." >&2
    return 2
  fi

  return 0
}

auto_select_window_if_needed || exit $?

ARGS=(smoke --timeout 25)
if [[ -n "$WINDOW" ]]; then ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then ARGS+=(--workspace "$WORKSPACE"); fi

"$SCRIPT_DIR/rpflow.sh" "${ARGS[@]}" >/dev/null

echo "Repo Prompt OK via rpflow. window=${WINDOW:-auto} tab=$TAB workspace=$WORKSPACE" >&2
