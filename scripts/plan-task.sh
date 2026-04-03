#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
BIND_PATH=""
SELECT_SET=""
CODEMAP_SET=""
TASK=""
OUT=""
COPY_PRESET="${RP_PLAN_COPY_PRESET:-mcpPlan}"
PROFILE="${RP_PROFILE:-normal}"
TIMEOUT="${RP_BUILDER_TIMEOUT:-300}"
PREFLIGHT_REPORT_JSON=""
STRICT=0
SLICE_SPECS=()

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-}"
DEFAULT_TAB="${RP_TAB:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  plan-task.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] [--bind REPO_DIR]
               --select-set PATHS --task TEXT --out FILE
               [--codemap PATHS] [--slice SPEC] [--copy-preset PRESET]
               [--profile fast|normal|deep] [--timeout SECONDS]
               [--preflight-report-json FILE] [--strict]

Notes:
  - Thin MCP-first planning wrapper: optional repo-path routing -> select -> context_builder(plan) -> export
  - --copy-preset defaults to mcpPlan; set it explicitly to override
  - --slice format: path:start-end[:description]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --bind|--path) BIND_PATH="$2"; shift 2 ;;
    --select-set) SELECT_SET="$2"; shift 2 ;;
    --codemap) CODEMAP_SET="$2"; shift 2 ;;
    --slice) SLICE_SPECS+=("$2"); shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --copy-preset) COPY_PRESET="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --preflight-report-json) PREFLIGHT_REPORT_JSON="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

if [[ -z "$SELECT_SET" || -z "$TASK" || -z "$OUT" ]]; then
  echo "Missing required args" >&2
  usage
  exit 2
fi

case "$PROFILE" in
  fast|normal|deep) ;;
  *) echo "Invalid --profile: $PROFILE (use fast|normal|deep)" >&2; exit 2 ;;
esac

if [[ -n "$TIMEOUT" ]] && ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] ; then
  echo "Invalid --timeout: $TIMEOUT (use integer seconds)" >&2
  exit 2
fi

FLOW_ARGS=(--select-set "$SELECT_SET" --task "$TASK" --builder-type plan --out "$OUT" --profile "$PROFILE")
if [[ -n "$WINDOW" ]]; then FLOW_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then FLOW_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then FLOW_ARGS+=(--workspace "$WORKSPACE"); fi
if [[ -n "$BIND_PATH" ]]; then FLOW_ARGS+=(--bind "$BIND_PATH"); fi
if [[ -n "$TIMEOUT" ]]; then FLOW_ARGS+=(--timeout "$TIMEOUT"); fi
if [[ -n "$CODEMAP_SET" ]]; then FLOW_ARGS+=(--codemap "$CODEMAP_SET"); fi
if [[ -n "$COPY_PRESET" ]]; then FLOW_ARGS+=(--copy-preset "$COPY_PRESET"); fi
if [[ -n "$PREFLIGHT_REPORT_JSON" ]]; then FLOW_ARGS+=(--preflight-report-json "$PREFLIGHT_REPORT_JSON"); fi
if [[ "$STRICT" -eq 1 ]]; then FLOW_ARGS+=(--strict); fi
if (( ${#SLICE_SPECS[@]} > 0 )); then
  for slice_spec in "${SLICE_SPECS[@]}"; do
    FLOW_ARGS+=(--slice "$slice_spec")
  done
fi

bash "$SCRIPT_DIR/context-flow.sh" "${FLOW_ARGS[@]}"
echo "Plan exported to: $OUT" >&2
