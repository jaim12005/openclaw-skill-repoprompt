#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
PROFILE="${RP_PROFILE:-normal}"
TIMEOUT=""
REPORT_JSON=""
STRICT=0

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_TAB="${RP_TAB:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  preflight.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME]
               [--profile fast|normal|deep] [--timeout SECONDS]
               [--report-json FILE] [--strict]

Checks:
  - rpflow available (via scripts/rpflow.sh)
  - Repo Prompt routing health (tabs/context/tools-schema) via rpflow smoke

Behavior:
  - If no window is provided, preflight probes windows via rpflow exec -e 'windows'
  - If exactly one window is found, it is auto-selected
  - If multiple windows are found, exits with guidance to set -w / RP_WINDOW

Environment defaults:
  RP_WINDOW (optional), RP_TAB (optional), RP_WORKSPACE (optional),
  RP_PROFILE (default: normal)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --report-json) REPORT_JSON="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

case "$PROFILE" in
  fast|normal|deep) ;;
  *) echo "Invalid --profile: $PROFILE (use fast|normal|deep)" >&2; exit 2 ;;
esac

auto_select_window_if_needed() {
  if [[ -n "$WINDOW" || "$STRICT" -eq 1 ]]; then
    return 0
  fi

  local windows_out
  if ! windows_out="$($SCRIPT_DIR/rpflow.sh exec --profile fast --raw-json -e 'windows' 2>&1)"; then
    # Fall through; smoke will emit the actionable error if routing is broken.
    return 0
  fi

  local window_ids
  window_ids="$(WINDOWS_OUT="$windows_out" python3 - <<'PY'
import json, os
text = os.environ.get('WINDOWS_OUT', '').strip()
ids = []
try:
    payload = json.loads(text)
except Exception:
    print('')
    raise SystemExit(0)
windows = payload.get('windows') if isinstance(payload, dict) else payload
if not isinstance(windows, list):
    windows = []
for item in windows:
    if not isinstance(item, dict):
        continue
    wid = item.get('window_id', item.get('windowID'))
    if wid is None:
        continue
    wid = str(wid)
    if wid not in ids:
        ids.append(wid)
print(' '.join(ids))
PY
)"

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

ARGS=(smoke --profile "$PROFILE")
if [[ -n "$TIMEOUT" ]]; then ARGS+=(--timeout "$TIMEOUT"); fi
if [[ -n "$REPORT_JSON" ]]; then ARGS+=(--report-json "$REPORT_JSON"); fi
if [[ "$STRICT" -eq 1 ]]; then ARGS+=(--strict); fi
if [[ -n "$WINDOW" ]]; then ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then ARGS+=(--workspace "$WORKSPACE"); fi

"$SCRIPT_DIR/rpflow.sh" "${ARGS[@]}" >/dev/null

echo "Repo Prompt OK via rpflow. window=${WINDOW:-auto} tab=${TAB:-auto} workspace=${WORKSPACE:-auto} profile=$PROFILE" >&2
