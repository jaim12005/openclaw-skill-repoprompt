#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
BIND_PATH=""
SELECT_SET=""
CODEMAP_SET=""
OUT=""
TASK=""
BUILDER_TYPE=""
COPY_PRESET=""
PROFILE="${RP_PROFILE:-normal}"
TIMEOUT=""
RETRY_ON_TIMEOUT=0
RETRY_TIMEOUT=""
RETRY_TIMEOUT_SCALE="2.0"
FALLBACK_EXPORT_ON_TIMEOUT=0
PREFLIGHT_REPORT_JSON=""
STRICT=0
SLICE_SPECS=()

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_TAB="${RP_TAB:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-}"

usage() {
  cat <<'USAGE'
Usage:
  context-flow.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] [--bind REPO_DIR] \
    --select-set PATHS --out FILE \
    [--task TEXT] [--builder-type clarify|question|plan|review] \
    [--copy-preset PRESET] [--profile fast|normal|deep] [--timeout SECONDS] \
    [--retry-on-timeout] [--retry-timeout SECONDS] [--retry-timeout-scale FLOAT] \
    [--fallback-export-on-timeout] \
    [--preflight-report-json FILE] [--codemap PATHS] [--slice SPEC ...] [--strict]

Notes:
  - PATHS are comma-separated (e.g. repo/,src/,README.md)
  - --bind resolves the matching Repo Prompt workspace by root path for this invocation
  - --task runs MCP-native `context_builder`
  - --codemap adds codemap_only entries (reference context)
  - --slice format: path:start-end[:description]
  - Use multiple --slice flags for multiple ranges
  - Export writes to a temp file and only replaces --out on success
  - With --fallback-export-on-timeout, the script still succeeds if Builder times out,
    but the output artifact is context-only (no Builder-generated plan/review text)
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
    --builder-type) BUILDER_TYPE="$2"; shift 2 ;;
    --copy-preset) COPY_PRESET="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --retry-on-timeout) RETRY_ON_TIMEOUT=1; shift ;;
    --retry-timeout) RETRY_TIMEOUT="$2"; shift 2 ;;
    --retry-timeout-scale) RETRY_TIMEOUT_SCALE="$2"; shift 2 ;;
    --fallback-export-on-timeout) FALLBACK_EXPORT_ON_TIMEOUT=1; shift ;;
    --preflight-report-json) PREFLIGHT_REPORT_JSON="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

if [[ -z "$SELECT_SET" || -z "$OUT" ]]; then
  echo "Missing required args" >&2
  usage
  exit 2
fi

if [[ -n "$BUILDER_TYPE" ]]; then
  case "$BUILDER_TYPE" in
    clarify|question|plan|review) ;;
    *) echo "Invalid --builder-type: $BUILDER_TYPE" >&2; exit 2 ;;
  esac
fi

case "$PROFILE" in
  fast|normal|deep) ;;
  *) echo "Invalid --profile: $PROFILE (use fast|normal|deep)" >&2; exit 2 ;;
esac

validate_int_arg() {
  local label="$1"
  local value="$2"
  if [[ -n "$value" ]] && ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "Invalid $label: $value (use integer seconds)" >&2
    exit 2
  fi
}

validate_int_arg --timeout "$TIMEOUT"
validate_int_arg --retry-timeout "$RETRY_TIMEOUT"

if [[ -n "$RETRY_TIMEOUT_SCALE" ]]; then
  RETRY_TIMEOUT_SCALE="$(RETRY_TIMEOUT_SCALE="$RETRY_TIMEOUT_SCALE" python3 - <<'PY'
import os
raw = os.environ['RETRY_TIMEOUT_SCALE']
value = float(raw)
if value <= 1.0:
    raise SystemExit(f"Invalid --retry-timeout-scale: {raw} (must be > 1.0)")
print(value)
PY
)"
fi

if [[ -z "$TIMEOUT" && -n "$TASK" ]]; then
  TIMEOUT=300
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "$BIND_PATH" && -z "$WORKSPACE" ]]; then
  WORKSPACE_INVENTORY_JSON="$($SCRIPT_DIR/rpflow.sh exec --profile fast --raw-json -e 'call manage_workspaces {"action":"list"}')"
  WORKSPACE="$(BIND_PATH="$BIND_PATH" WORKSPACE_INVENTORY_JSON="$WORKSPACE_INVENTORY_JSON" python3 - <<'PY'
import json, os
from pathlib import Path
bind_path = Path(os.environ['BIND_PATH']).expanduser().resolve()
if not bind_path.exists():
    raise SystemExit(f"Path does not exist: {bind_path}")
if not bind_path.is_dir():
    raise SystemExit(f"Path is not a directory: {bind_path}")
payload = json.loads(os.environ['WORKSPACE_INVENTORY_JSON'])
workspaces = payload.get('workspaces', []) if isinstance(payload, dict) else []
bind_str = str(bind_path)
best = None
best_len = -1
for ws in workspaces:
    name = ws.get('name')
    for repo_path in ws.get('repo_paths', []) or []:
        root = Path(repo_path).expanduser().resolve()
        root_str = str(root)
        if bind_str == root_str or bind_str.startswith(root_str + os.sep):
            if len(root_str) > best_len:
                best = name
                best_len = len(root_str)
if not best:
    raise SystemExit(f"No loaded Repo Prompt workspace matches {bind_path}. Open the repo in Repo Prompt first or pass --workspace explicitly.")
print(best)
PY
)"
fi

PREFLIGHT_ARGS=()
if [[ -n "$WINDOW" ]]; then PREFLIGHT_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then PREFLIGHT_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then PREFLIGHT_ARGS+=(--workspace "$WORKSPACE"); fi
PREFLIGHT_ARGS+=(--profile "$PROFILE")
if [[ -n "$PREFLIGHT_REPORT_JSON" ]]; then PREFLIGHT_ARGS+=(--report-json "$PREFLIGHT_REPORT_JSON"); fi
if [[ "$STRICT" -eq 1 ]]; then PREFLIGHT_ARGS+=(--strict); fi
bash "$SCRIPT_DIR/preflight.sh" "${PREFLIGHT_ARGS[@]}" >/dev/null

SELECT_JSON=$(SELECT_SET="$SELECT_SET" python3 - <<'PY'
import json, os
paths = [p.strip() for p in os.environ.get('SELECT_SET', '').split(',') if p.strip()]
print(json.dumps(paths))
PY
)

CODEMAP_JSON=$(CODEMAP_SET="$CODEMAP_SET" python3 - <<'PY'
import json, os
paths = [p.strip() for p in os.environ.get('CODEMAP_SET', '').split(',') if p.strip()]
print(json.dumps(paths))
PY
)

SLICE_JSON=$(SLICE_SPECS="$(printf '%s\n' "${SLICE_SPECS[@]:-}")" python3 - <<'PY'
import json, os
slices = []
for spec in os.environ.get('SLICE_SPECS', '').splitlines():
    spec = spec.strip()
    if not spec:
        continue
    if ':' not in spec:
        raise SystemExit(f"Invalid slice spec: {spec}")
    path, rest = spec.split(':', 1)
    if ':' in rest:
        range_part, desc = rest.split(':', 1)
    else:
        range_part, desc = rest, ''
    if '-' not in range_part:
        raise SystemExit(f"Invalid slice range: {spec}")
    start, end = range_part.split('-', 1)
    rng = {"start_line": int(start), "end_line": int(end)}
    if desc:
        rng["description"] = desc
    slices.append({"path": path, "ranges": [rng]})
print(json.dumps(slices))
PY
)

BUILDER_JSON=""
if [[ -n "$TASK" ]]; then
  BUILDER_JSON="$(TASK="$TASK" BUILDER_TYPE="$BUILDER_TYPE" python3 - <<'PY'
import json, os
payload = {
    "instructions": os.environ["TASK"],
    "response_type": os.environ.get("BUILDER_TYPE", "").strip() or "clarify",
}
print(json.dumps(payload))
PY
)"
fi

OUT_DIR="$(dirname "$OUT")"
mkdir -p "$OUT_DIR"
TMP_OUT="$(OUT_DIR="$OUT_DIR" python3 - <<'PY'
import os, tempfile
out_dir = os.environ['OUT_DIR']
fd, path = tempfile.mkstemp(prefix='.rpflow-export.', suffix='.md', dir=out_dir)
os.close(fd)
os.unlink(path)
print(path)
PY
)"
cleanup() {
  rm -f "$TMP_OUT"
}
trap cleanup EXIT

EXPORT_JSON="$(OUT_PATH="$TMP_OUT" COPY_PRESET="$COPY_PRESET" python3 - <<'PY'
import json, os
payload = {"op": "export", "path": os.environ["OUT_PATH"]}
copy_preset = os.environ.get("COPY_PRESET", "").strip()
if copy_preset:
    payload["copy_preset"] = copy_preset
print(json.dumps(payload))
PY
)"

SELECTION_CMD='call manage_selection {"op":"clear"}'
if [[ "$SELECT_JSON" != "[]" ]]; then
  SELECTION_CMD+=" && call manage_selection {\"op\":\"add\",\"paths\":$SELECT_JSON,\"mode\":\"full\"}"
fi
if [[ "$CODEMAP_JSON" != "[]" ]]; then
  SELECTION_CMD+=" && call manage_selection {\"op\":\"add\",\"paths\":$CODEMAP_JSON,\"mode\":\"codemap_only\"}"
fi
if [[ "$SLICE_JSON" != "[]" ]]; then
  SELECTION_CMD+=" && call manage_selection {\"op\":\"add\",\"mode\":\"slices\",\"slices\":$SLICE_JSON}"
fi

EXPORT_CMD="call workspace_context $EXPORT_JSON"
FLOW_CMD="$SELECTION_CMD"
if [[ -n "$BUILDER_JSON" ]]; then
  FLOW_CMD+=" && call context_builder $BUILDER_JSON"
fi
FLOW_CMD+=" && $EXPORT_CMD"
FALLBACK_CMD="$SELECTION_CMD && $EXPORT_CMD"

calc_retry_timeout() {
  local current_timeout="$1"
  if [[ -n "$RETRY_TIMEOUT" ]]; then
    printf '%s\n' "$RETRY_TIMEOUT"
    return 0
  fi
  CURRENT_TIMEOUT="$current_timeout" RETRY_TIMEOUT_SCALE="$RETRY_TIMEOUT_SCALE" python3 - <<'PY'
import math, os
current = int(os.environ['CURRENT_TIMEOUT'])
scale = float(os.environ['RETRY_TIMEOUT_SCALE'])
print(max(current + 1, int(math.ceil(current * scale))))
PY
}

run_exec_flow() {
  local cmd="$1"
  local timeout_value="$2"
  local args=(exec --profile "$PROFILE")
  if [[ -n "$WINDOW" ]]; then args+=(--window "$WINDOW"); fi
  if [[ -n "$TAB" ]]; then args+=(--tab "$TAB"); fi
  if [[ -n "$WORKSPACE" ]]; then args+=(--workspace "$WORKSPACE"); fi
  if [[ -n "$timeout_value" ]]; then args+=(--timeout "$timeout_value"); fi
  if [[ "$STRICT" -eq 1 ]]; then args+=(--strict); fi
  args+=(-e "$cmd")

  "$SCRIPT_DIR/rpflow.sh" "${args[@]}"
}

RETRY_USED=0

if [[ -z "$BUILDER_JSON" ]]; then
  run_exec_flow "$FALLBACK_CMD" "$TIMEOUT"
  mv "$TMP_OUT" "$OUT"
  echo "Prompt/context exported to: $OUT" >&2
  exit 0
fi

BUILDER_TIMEOUT_MSG="Context Builder timed out"
if [[ -n "$TIMEOUT" ]]; then
  echo "Running Context Builder flow with timeout=${TIMEOUT}s..." >&2
fi

set +e
run_exec_flow "$FLOW_CMD" "$TIMEOUT"
FIRST_STATUS=$?
set -e
if [[ "$FIRST_STATUS" -eq 0 ]]; then
  mv "$TMP_OUT" "$OUT"
  echo "Prompt/context exported to: $OUT" >&2
  exit 0
fi
if [[ "$FIRST_STATUS" -ne 124 ]]; then
  echo "Context Builder flow failed (exit=$FIRST_STATUS). No fallback applied." >&2
  exit "$FIRST_STATUS"
fi

if [[ "$RETRY_ON_TIMEOUT" -eq 1 ]]; then
  RETRY_USED=1
  EFFECTIVE_RETRY_TIMEOUT="$(calc_retry_timeout "$TIMEOUT")"
  echo "$BUILDER_TIMEOUT_MSG after ${TIMEOUT:-unknown}s; retrying once with timeout=${EFFECTIVE_RETRY_TIMEOUT}s..." >&2
  rm -f "$TMP_OUT"
  set +e
  run_exec_flow "$FLOW_CMD" "$EFFECTIVE_RETRY_TIMEOUT"
  SECOND_STATUS=$?
  set -e
  if [[ "$SECOND_STATUS" -eq 0 ]]; then
    mv "$TMP_OUT" "$OUT"
    echo "Prompt/context exported to: $OUT (Context Builder succeeded on retry)" >&2
    exit 0
  fi
  if [[ "$SECOND_STATUS" -ne 124 ]]; then
    echo "Context Builder retry failed (exit=$SECOND_STATUS). No timeout fallback applied." >&2
    exit "$SECOND_STATUS"
  fi
  TIMEOUT="$EFFECTIVE_RETRY_TIMEOUT"
fi

if [[ "$FALLBACK_EXPORT_ON_TIMEOUT" -eq 1 ]]; then
  if [[ "$RETRY_USED" -eq 1 ]]; then
    echo "$BUILDER_TIMEOUT_MSG after retry; exporting context-only artifact instead..." >&2
  else
    echo "$BUILDER_TIMEOUT_MSG; exporting context-only artifact instead..." >&2
  fi
  rm -f "$TMP_OUT"
  run_exec_flow "$FALLBACK_CMD" "$TIMEOUT"
  mv "$TMP_OUT" "$OUT"
  echo "Prompt/context exported to: $OUT (fallback export used; Builder output missing due to timeout)" >&2
  exit 0
fi

if [[ "$RETRY_USED" -eq 1 ]]; then
  echo "$BUILDER_TIMEOUT_MSG again after retry. Re-run with a longer --timeout or use --fallback-export-on-timeout." >&2
else
  echo "$BUILDER_TIMEOUT_MSG. Re-run with a longer --timeout, --retry-on-timeout, or --fallback-export-on-timeout." >&2
fi
exit 124
