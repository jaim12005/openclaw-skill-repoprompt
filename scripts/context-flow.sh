#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
SELECT_SET=""
CODEMAP_SET=""
OUT=""
TASK=""
BUILDER_TYPE=""
SLICE_SPECS=()

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_TAB="${RP_TAB:-T1}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"

usage() {
  cat <<'USAGE'
Usage:
  context-flow.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] \
    --select-set PATHS --out FILE \
    [--task TEXT] [--builder-type clarify|question|plan|review] \
    [--codemap PATHS] [--slice SPEC ...]

Notes:
  - PATHS are comma-separated (e.g. repo/,src/,README.md)
  - --task runs Context Builder for discovery
  - --codemap adds codemap_only entries (reference context)
  - --slice format: path:start-end[:description]
  - Use multiple --slice flags for multiple ranges
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2;;
    -t|--tab) TAB="$2"; shift 2;;
    --workspace) WORKSPACE="$2"; shift 2;;
    --select-set) SELECT_SET="$2"; shift 2;;
    --codemap) CODEMAP_SET="$2"; shift 2;;
    --slice) SLICE_SPECS+=("$2"); shift 2;;
    --task) TASK="$2"; shift 2;;
    --builder-type) BUILDER_TYPE="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

# Defaults
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
    *) echo "Invalid --builder-type: $BUILDER_TYPE" >&2; exit 2;;
  esac
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/preflight.sh" ${WINDOW:+-w "$WINDOW"} ${TAB:+-t "$TAB"} --workspace "$WORKSPACE" >/dev/null

SELECT_JSON=$(SELECT_SET="$SELECT_SET" python3 - <<'PY'
import json, os
paths = [p.strip() for p in os.environ.get('SELECT_SET','').split(',') if p.strip()]
print(json.dumps(paths))
PY
)

CODEMAP_JSON=$(CODEMAP_SET="$CODEMAP_SET" python3 - <<'PY'
import json, os
paths = [p.strip() for p in os.environ.get('CODEMAP_SET','').split(',') if p.strip()]
print(json.dumps(paths))
PY
)

SLICE_JSON=$(SLICE_SPECS="$(printf '%s\n' "${SLICE_SPECS[@]:-}")" python3 - <<'PY'
import json, os
slices = []
for spec in os.environ.get('SLICE_SPECS','').splitlines():
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

ARGS=()
if [[ -n "$WINDOW" ]]; then ARGS+=("-w" "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=("-t" "$TAB"); fi

CMD="workspace switch \"$WORKSPACE\" && call manage_selection {\"op\":\"clear\"}"
if [[ "$SELECT_JSON" != "[]" ]]; then
  CMD+=" && call manage_selection {\"op\":\"add\",\"paths\":$SELECT_JSON,\"mode\":\"full\"}"
fi

if [[ -n "$TASK" ]]; then
  if [[ -n "$BUILDER_TYPE" ]]; then
    CMD+=" && builder $(printf %q "$TASK") --type \"$BUILDER_TYPE\""
  else
    CMD+=" && builder $(printf %q "$TASK")"
  fi
fi

if [[ "$CODEMAP_JSON" != "[]" ]]; then
  CMD+=" && call manage_selection {\"op\":\"add\",\"paths\":$CODEMAP_JSON,\"mode\":\"codemap_only\"}"
fi

if [[ "$SLICE_JSON" != "[]" ]]; then
  CMD+=" && call manage_selection {\"op\":\"add\",\"mode\":\"slices\",\"slices\":$SLICE_JSON}"
fi

CMD+=" && prompt export \"$OUT\""

rp-cli "${ARGS[@]}" -e "$CMD"
echo "Prompt exported to: $OUT" >&2
