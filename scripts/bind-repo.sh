#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
BIND_PATH=""
PROFILE="${RP_PROFILE:-normal}"
STRICT=0

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_TAB="${RP_TAB:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  bind-repo.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] --path REPO_DIR
               [--profile fast|normal|deep] [--strict]

Notes:
  - Resolves the matching Repo Prompt workspace by root path
  - Switches the current Repo Prompt window to that workspace
  - Auto-uses the single showing window for that workspace when possible
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --path|--bind) BIND_PATH="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

if [[ -z "$BIND_PATH" ]]; then
  echo "Missing --path/--bind" >&2
  usage
  exit 2
fi

case "$PROFILE" in
  fast|normal|deep) ;;
  *) echo "Invalid --profile: $PROFILE (use fast|normal|deep)" >&2; exit 2 ;;
esac

CANONICAL_PATH="$(BIND_PATH="$BIND_PATH" python3 - <<'PY'
from pathlib import Path
import os
path = Path(os.environ['BIND_PATH']).expanduser().resolve()
if not path.exists():
    raise SystemExit(f"Path does not exist: {path}")
if not path.is_dir():
    raise SystemExit(f"Path is not a directory: {path}")
print(path)
PY
)"

WORKSPACE_INVENTORY_JSON="$($SCRIPT_DIR/rpflow.sh exec --profile fast --raw-json -e 'call manage_workspaces {"action":"list"}')"

RESOLVED_JSON="$(BIND_PATH="$CANONICAL_PATH" WORKSPACE_HINT="$WORKSPACE" WORKSPACE_INVENTORY_JSON="$WORKSPACE_INVENTORY_JSON" python3 - <<'PY'
import json, os
from pathlib import Path
bind_path = Path(os.environ['BIND_PATH']).expanduser().resolve()
workspace_hint = os.environ.get('WORKSPACE_HINT', '').strip()
payload = json.loads(os.environ['WORKSPACE_INVENTORY_JSON'])
workspaces = payload.get('workspaces', []) if isinstance(payload, dict) else []
bind_str = str(bind_path)
best = None
best_len = -1
for ws in workspaces:
    name = ws.get('name')
    if workspace_hint and name == workspace_hint:
        best = ws
        break
    for repo_path in ws.get('repo_paths', []) or []:
        root = Path(repo_path).expanduser().resolve()
        root_str = str(root)
        if bind_str == root_str or bind_str.startswith(root_str + os.sep):
            if len(root_str) > best_len:
                best = ws
                best_len = len(root_str)
if not best:
    raise SystemExit(f"No loaded Repo Prompt workspace matches {bind_path}. Open the repo in Repo Prompt first or pass --workspace explicitly.")
showing = best.get('showing_window_ids') or []
window_id = showing[0] if len(showing) == 1 else None
print(json.dumps({"workspace": best.get('name'), "window_id": window_id}))
PY
)"

if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="$(RESOLVED_JSON="$RESOLVED_JSON" python3 - <<'PY'
import json, os
print(json.loads(os.environ['RESOLVED_JSON'])['workspace'])
PY
)"
fi

if [[ -z "$WINDOW" ]]; then
  WINDOW="$(RESOLVED_JSON="$RESOLVED_JSON" python3 - <<'PY'
import json, os
value = json.loads(os.environ['RESOLVED_JSON']).get('window_id')
print('' if value is None else value)
PY
)"
fi

SWITCH_JSON="$(WORKSPACE_NAME="$WORKSPACE" python3 - <<'PY'
import json, os
print(json.dumps({"action": "switch", "workspace": os.environ['WORKSPACE_NAME']}))
PY
)"

ARGS=(exec --profile "$PROFILE" -e "call manage_workspaces $SWITCH_JSON")
if [[ -n "$WINDOW" ]]; then ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then ARGS+=(--tab "$TAB"); fi
if [[ "$STRICT" -eq 1 ]]; then ARGS+=(--strict); fi

set +e
CMD_OUTPUT="$($SCRIPT_DIR/rpflow.sh "${ARGS[@]}" 2>&1)"
CMD_STATUS=$?
set -e

if [[ "$CMD_STATUS" -ne 0 ]]; then
  if printf '%s' "$CMD_OUTPUT" | grep -q 'Already on workspace'; then
    printf '%s\n' "$CMD_OUTPUT"
  else
    printf '%s\n' "$CMD_OUTPUT" >&2
    exit "$CMD_STATUS"
  fi
else
  printf '%s\n' "$CMD_OUTPUT"
fi

echo "Repo Prompt switched to workspace: $WORKSPACE ($CANONICAL_PATH)" >&2
