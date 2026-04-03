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
    [--copy-preset PRESET] [--profile fast|normal|deep] \
    [--preflight-report-json FILE] [--codemap PATHS] [--slice SPEC ...] [--strict]

Notes:
  - PATHS are comma-separated (e.g. repo/,src/,README.md)
  - --bind resolves the matching Repo Prompt workspace by root path for this invocation
  - --task runs MCP-native `context_builder`
  - --codemap adds codemap_only entries (reference context)
  - --slice format: path:start-end[:description]
  - Use multiple --slice flags for multiple ranges
  - Export writes to a temp file and only replaces --out on success
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

CMD='call manage_selection {"op":"clear"}'
if [[ "$SELECT_JSON" != "[]" ]]; then
  CMD+=" && call manage_selection {\"op\":\"add\",\"paths\":$SELECT_JSON,\"mode\":\"full\"}"
fi
if [[ "$CODEMAP_JSON" != "[]" ]]; then
  CMD+=" && call manage_selection {\"op\":\"add\",\"paths\":$CODEMAP_JSON,\"mode\":\"codemap_only\"}"
fi
if [[ "$SLICE_JSON" != "[]" ]]; then
  CMD+=" && call manage_selection {\"op\":\"add\",\"mode\":\"slices\",\"slices\":$SLICE_JSON}"
fi
if [[ -n "$BUILDER_JSON" ]]; then
  CMD+=" && call context_builder $BUILDER_JSON"
fi
CMD+=" && call workspace_context $EXPORT_JSON"

RPF_ARGS=(exec --profile "$PROFILE" -e "$CMD")
if [[ -n "$WINDOW" ]]; then RPF_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then RPF_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then RPF_ARGS+=(--workspace "$WORKSPACE"); fi
if [[ "$STRICT" -eq 1 ]]; then RPF_ARGS+=(--strict); fi

"$SCRIPT_DIR/rpflow.sh" "${RPF_ARGS[@]}"
mv "$TMP_OUT" "$OUT"
echo "Prompt/context exported to: $OUT" >&2
