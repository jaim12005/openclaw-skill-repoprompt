#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
CMD=""

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"
DEFAULT_TAB="${RP_TAB:-T1}"

usage() {
  cat <<'USAGE'
Usage:
  rp.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] -e '...'

Notes:
  - Runs a safe workspace switch first when --workspace (or RP_WORKSPACE) is set.
  - "Already on workspace" is treated as success.
  - If -t/--tab is omitted, defaults to RP_TAB (or T1).
  - If -w/--window is omitted, defaults to RP_WINDOW if set.

Examples:
  rp.sh -e 'windows'
  rp.sh --workspace GitHub -e 'tree --folders'
  rp.sh -w 1 -t T1 --workspace MyRepo -e 'select set src/ && builder "Find auth code" --type plan'
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
    -e|--exec) CMD="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
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

ARGS=()
if [[ -n "$WINDOW" ]]; then ARGS+=("-w" "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=("-t" "$TAB"); fi

safe_workspace_switch() {
  local ws="$1"
  [[ -z "$ws" ]] && return 0

  local out rc
  set +e
  out=$(rp-cli "${ARGS[@]}" -e "workspace switch \"$ws\"" 2>&1)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    return 0
  fi

  if echo "$out" | grep -qi 'already on workspace'; then
    return 0
  fi

  echo "$out" >&2
  return $rc
}

safe_workspace_switch "$WORKSPACE"
exec rp-cli "${ARGS[@]}" -e "$CMD"
