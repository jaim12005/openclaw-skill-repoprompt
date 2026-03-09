#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
SELECT_SET=""
TASK=""
OUT=""
PROFILE="${RP_PROFILE:-normal}"
REPORT_JSON=""
TIMEOUT=""
PREFLIGHT_TIMEOUT=""
RETRY_TIMEOUT=""
RETRY_TIMEOUT_SCALE=""
RESUME_FROM_EXPORT=""
STRICT=0

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"
DEFAULT_TAB="${RP_TAB:-T1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  plan-export.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] --select-set PATHS --task TEXT --out FILE
                 [--profile fast|normal|deep] [--report-json FILE] [--timeout SECONDS]
                 [--preflight-timeout SECONDS] [--retry-timeout SECONDS]
                 [--retry-timeout-scale FLOAT] [--resume-from-export FILE] [--strict]

Notes:
  - PATHS is a comma-separated list (e.g. repo/,src/,README.md)
  - Runs rpflow autopilot (preflight + builder plan + prompt export)
  - Includes retry-on-timeout and fallback export by default
  - Defaults: RP_WINDOW (optional), RP_TAB (or T1), RP_WORKSPACE (or GitHub), RP_PROFILE (or normal)
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
    --profile) PROFILE="$2"; shift 2 ;;
    --report-json) REPORT_JSON="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --preflight-timeout) PREFLIGHT_TIMEOUT="$2"; shift 2 ;;
    --retry-timeout) RETRY_TIMEOUT="$2"; shift 2 ;;
    --retry-timeout-scale) RETRY_TIMEOUT_SCALE="$2"; shift 2 ;;
    --resume-from-export) RESUME_FROM_EXPORT="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
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

case "$PROFILE" in
  fast|normal|deep) ;;
  *) echo "Invalid --profile: $PROFILE (use fast|normal|deep)" >&2; exit 2 ;;
esac

ARGS=(autopilot --profile "$PROFILE" --select-set "$SELECT_SET" --task "$TASK" --out "$OUT" --retry-on-timeout --fallback-export-on-timeout)
if [[ -n "$REPORT_JSON" ]]; then ARGS+=(--report-json "$REPORT_JSON"); fi
if [[ -n "$TIMEOUT" ]]; then ARGS+=(--timeout "$TIMEOUT"); fi
if [[ -n "$PREFLIGHT_TIMEOUT" ]]; then ARGS+=(--preflight-timeout "$PREFLIGHT_TIMEOUT"); fi
if [[ -n "$RETRY_TIMEOUT" ]]; then ARGS+=(--retry-timeout "$RETRY_TIMEOUT"); fi
if [[ -n "$RETRY_TIMEOUT_SCALE" ]]; then ARGS+=(--retry-timeout-scale "$RETRY_TIMEOUT_SCALE"); fi
if [[ -n "$RESUME_FROM_EXPORT" ]]; then ARGS+=(--resume-from-export "$RESUME_FROM_EXPORT"); fi
if [[ "$STRICT" -eq 1 ]]; then ARGS+=(--strict); fi
if [[ -n "$WINDOW" ]]; then ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then ARGS+=(--workspace "$WORKSPACE"); fi

"$SCRIPT_DIR/rpflow.sh" "${ARGS[@]}"
echo "Plan + prompt exported to: $OUT" >&2
