#!/usr/bin/env bash
set -euo pipefail

RPFLOW_REPO="${RPFLOW_REPO:-$HOME/Documents/github/repoprompt-rpflow-cli}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"
DEFAULT_TAB="${RP_TAB:-T1}"

usage() {
  cat <<'USAGE'
Usage:
  rpflow.sh <subcommand> [args...]

Examples:
  rpflow.sh doctor
  rpflow.sh smoke --workspace GitHub --tab T1
  rpflow.sh exec -e 'tabs'
  rpflow.sh call --tool apply_edits --json-arg @edits.json
  rpflow.sh autopilot --select-set repo/src/ --task "draft plan" --out /tmp/plan.md

Behavior:
  - Runs rpflow from RPFLOW_REPO (default: $HOME/Documents/github/repoprompt-rpflow-cli)
  - For exec/call/export/plan-export/autopilot/smoke, injects default --workspace/--tab when not provided
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

SUBCMD="$1"
shift

if [[ ! -d "$RPFLOW_REPO" ]]; then
  echo "rpflow repo not found: $RPFLOW_REPO" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found in PATH" >&2
  exit 1
fi

ARGS=("$@")

needs_route_defaults() {
  case "$SUBCMD" in
    exec|call|export|plan-export|autopilot|smoke) return 0 ;;
    *) return 1 ;;
  esac
}

has_flag() {
  local needle="$1"
  shift || true
  for a in "$@"; do
    [[ "$a" == "$needle" ]] && return 0
  done
  return 1
}

if needs_route_defaults; then
  if ! has_flag "--workspace" "${ARGS[@]}"; then
    ARGS=(--workspace "$DEFAULT_WORKSPACE" "${ARGS[@]}")
  fi
  if ! has_flag "--tab" "${ARGS[@]}"; then
    ARGS=(--tab "$DEFAULT_TAB" "${ARGS[@]}")
  fi
fi

cd "$RPFLOW_REPO"
exec env PYTHONPATH=src python3 -m rpflow.cli "$SUBCMD" "${ARGS[@]}"
