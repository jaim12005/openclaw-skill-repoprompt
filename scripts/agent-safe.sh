#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
SELECT_SET=""
TASK=""
OUT=""
MODE="plan"
REASONING="${RP_AGENT_REASONING:-medium}"
MODEL="${RP_AGENT_MODEL:-current_chat_model}"
CHAT_NAME=""
NO_CHAT=0

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-GitHub}"
DEFAULT_TAB="${RP_TAB:-T1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  agent-safe.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] \
    --select-set PATHS --task TEXT --out FILE \
    [--mode plan|edit|review|chat] [--reasoning low|medium|high] \
    [--model MODEL_PRESET] [--chat-name NAME] [--no-chat]

What it does:
  1) Preflight Repo Prompt routing (smoke)
  2) Runs plan-export with retry + timeout fallback
  3) Sets a safety-focused tab prompt for Agent Mode
  4) Starts a new chat using the tab prompt (unless --no-chat)

Notes:
  - Codex-first behavior is enforced via prompt policy + model preset default.
  - Edit review/approval toggles are controlled in Repo Prompt UI; this script
    encodes the policy in the prompt so each run is explicit and auditable.
  - PATHS is comma-separated (e.g. repo/src/,repo/README.md)
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
    --mode) MODE="$2"; shift 2 ;;
    --reasoning) REASONING="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --chat-name) CHAT_NAME="$2"; shift 2 ;;
    --no-chat) NO_CHAT=1; shift ;;
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

case "$MODE" in
  plan|edit|review|chat) ;;
  *) echo "Invalid --mode: $MODE" >&2; exit 2 ;;
esac

case "$REASONING" in
  low|medium|high) ;;
  *) echo "Invalid --reasoning: $REASONING (use low|medium|high)" >&2; exit 2 ;;
esac

if [[ -z "$CHAT_NAME" ]]; then
  CHAT_NAME="agent-safe-$(date +%Y%m%d-%H%M%S)"
fi

# 1) Preflight routing
bash "$SCRIPT_DIR/preflight.sh" ${WINDOW:+-w "$WINDOW"} ${TAB:+-t "$TAB"} --workspace "$WORKSPACE" >/dev/null

# 2) Deterministic context + export artifact
bash "$SCRIPT_DIR/plan-export.sh" ${WINDOW:+-w "$WINDOW"} ${TAB:+-t "$TAB"} --workspace "$WORKSPACE" --select-set "$SELECT_SET" --task "$TASK" --out "$OUT" >/dev/null

# 3) Set explicit Agent safety policy in tab prompt
PROMPT_FILE="$(mktemp /tmp/rp-agent-safe-prompt.XXXXXX.txt)"
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<EOF
<taskname="Repo Prompt Agent Safe Run"/>

<policy>
- Provider preference: Codex-first; fallback providers only when Codex is unavailable for this task.
- Reasoning effort target: $REASONING.
- Scope guard: operate only on currently selected files unless expansion is explicitly approved.
- Approval policy: for risky, broad, or destructive edits, require a plan + explicit approval before editing.
- Change style: small, reviewable diffs with rationale.
</policy>

<task>
$TASK
</task>

<context_artifacts>
- prompt_export_path: $OUT
</context_artifacts>

<execution>
1) Start with a concrete plan.
2) Highlight risk points and affected files.
3) Ask for confirmation before broad/risky edits.
4) Keep final changes scoped and auditable.
</execution>
EOF

PROMPT_JSON="$(python3 - "$PROMPT_FILE" <<'PY'
import json, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
print(json.dumps({"op": "set", "text": text}))
PY
)"

RPF_ARGS=(call --tool prompt --json-arg "$PROMPT_JSON")
if [[ -n "$WINDOW" ]]; then RPF_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then RPF_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then RPF_ARGS+=(--workspace "$WORKSPACE"); fi
"$SCRIPT_DIR/rpflow.sh" "${RPF_ARGS[@]}" >/dev/null

if [[ "$NO_CHAT" -eq 1 ]]; then
  echo "Agent-safe setup complete. Context exported to: $OUT" >&2
  echo "Prompt policy set. Start chat manually when ready." >&2
  exit 0
fi

# 4) Start new Agent chat with tab prompt
CHAT_JSON="$(MODE="$MODE" MODEL="$MODEL" CHAT_NAME="$CHAT_NAME" python3 - <<'PY'
import json, os
payload = {
  "new_chat": True,
  "mode": os.environ["MODE"],
  "use_tab_prompt": True,
  "chat_name": os.environ["CHAT_NAME"],
  "message": "Use tab prompt"
}
model = os.environ.get("MODEL", "").strip()
if model and model.lower() != "auto":
  payload["model"] = model
print(json.dumps(payload))
PY
)"

CHAT_ARGS=(call --tool chat_send --json-arg "$CHAT_JSON")
if [[ -n "$WINDOW" ]]; then CHAT_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then CHAT_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then CHAT_ARGS+=(--workspace "$WORKSPACE"); fi

"$SCRIPT_DIR/rpflow.sh" "${CHAT_ARGS[@]}"

echo "Agent-safe run complete. Context export: $OUT" >&2
