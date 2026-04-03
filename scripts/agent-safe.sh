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
MODEL_ID="${RP_AGENT_MODEL_ID:-engineer}"
WORKFLOW_NAME=""
PROFILE="${RP_PROFILE:-normal}"
REPORT_JSON=""
TIMEOUT=""
PREFLIGHT_TIMEOUT=""
RETRY_TIMEOUT=""
RETRY_TIMEOUT_SCALE=""
RESUME_FROM_EXPORT=""
CHAT_NAME=""
NO_CHAT=0
STRICT=0

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-}"
DEFAULT_TAB="${RP_TAB:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  agent-safe.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] \
    --select-set PATHS --task TEXT --out FILE \
    [--mode plan|edit|review|chat] [--reasoning low|medium|high] \
    [--model-id ROLE_OR_MODEL] [--workflow-name NAME] [--profile fast|normal|deep] \
    [--report-json FILE] [--timeout SECONDS] [--preflight-timeout SECONDS] \
    [--retry-timeout SECONDS] [--retry-timeout-scale FLOAT] \
    [--resume-from-export FILE] [--chat-name NAME] [--no-chat] [--strict]

What it does:
  1) Runs plan-export with retry + timeout fallback
  2) Sets a safety-focused tab prompt for Agent Mode
  3) Starts a new Agent Mode run via MCP `agent_run` (unless --no-chat)

Notes:
  - `--model-id` accepts Repo Prompt role labels (`explore`, `engineer`, `pair`, `design`) or a concrete model_id from `agent_manage list_agents`.
  - `--workflow-name` defaults from `--mode` (`Plan & Build`, `Refactor`, `Review`, `Investigate`).
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
    --model|--model-id) MODEL_ID="$2"; shift 2 ;;
    --workflow-name) WORKFLOW_NAME="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --report-json) REPORT_JSON="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --preflight-timeout) PREFLIGHT_TIMEOUT="$2"; shift 2 ;;
    --retry-timeout) RETRY_TIMEOUT="$2"; shift 2 ;;
    --retry-timeout-scale) RETRY_TIMEOUT_SCALE="$2"; shift 2 ;;
    --resume-from-export) RESUME_FROM_EXPORT="$2"; shift 2 ;;
    --chat-name) CHAT_NAME="$2"; shift 2 ;;
    --no-chat) NO_CHAT=1; shift ;;
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

case "$MODE" in
  plan|edit|review|chat) ;;
  *) echo "Invalid --mode: $MODE" >&2; exit 2 ;;
esac

case "$REASONING" in
  low|medium|high) ;;
  *) echo "Invalid --reasoning: $REASONING (use low|medium|high)" >&2; exit 2 ;;
esac

case "$PROFILE" in
  fast|normal|deep) ;;
  *) echo "Invalid --profile: $PROFILE (use fast|normal|deep)" >&2; exit 2 ;;
esac

if [[ -z "$CHAT_NAME" ]]; then
  CHAT_NAME="agent-safe-$(date +%Y%m%d-%H%M%S)"
fi

if [[ -z "$WORKFLOW_NAME" ]]; then
  case "$MODE" in
    plan) WORKFLOW_NAME="Plan & Build" ;;
    edit) WORKFLOW_NAME="Refactor" ;;
    review) WORKFLOW_NAME="Review" ;;
    chat) WORKFLOW_NAME="Investigate" ;;
  esac
fi

PLAN_ARGS=()
if [[ -n "$WINDOW" ]]; then PLAN_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then PLAN_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then PLAN_ARGS+=(--workspace "$WORKSPACE"); fi
PLAN_ARGS+=(--select-set "$SELECT_SET" --task "$TASK" --out "$OUT" --profile "$PROFILE")
if [[ -n "$REPORT_JSON" ]]; then PLAN_ARGS+=(--report-json "$REPORT_JSON"); fi
if [[ -n "$TIMEOUT" ]]; then PLAN_ARGS+=(--timeout "$TIMEOUT"); fi
if [[ -n "$PREFLIGHT_TIMEOUT" ]]; then PLAN_ARGS+=(--preflight-timeout "$PREFLIGHT_TIMEOUT"); fi
if [[ -n "$RETRY_TIMEOUT" ]]; then PLAN_ARGS+=(--retry-timeout "$RETRY_TIMEOUT"); fi
if [[ -n "$RETRY_TIMEOUT_SCALE" ]]; then PLAN_ARGS+=(--retry-timeout-scale "$RETRY_TIMEOUT_SCALE"); fi
if [[ -n "$RESUME_FROM_EXPORT" ]]; then PLAN_ARGS+=(--resume-from-export "$RESUME_FROM_EXPORT"); fi
if [[ "$STRICT" -eq 1 ]]; then PLAN_ARGS+=(--strict); fi

# 1) Deterministic context + export artifact
bash "$SCRIPT_DIR/plan-export.sh" "${PLAN_ARGS[@]}" >/dev/null

# 2) Set explicit Agent safety policy in tab prompt
PROMPT_FILE="$(mktemp /tmp/rp-agent-safe-prompt.XXXXXX.txt)"
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<EOF
<taskname="Repo Prompt Agent Safe Run"/>

<policy>
- Provider preference: Codex-first agent routing. Default model hint: $MODEL_ID.
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

RPF_ARGS=(call --profile "$PROFILE" --tool prompt --json-arg "$PROMPT_JSON")
if [[ -n "$WINDOW" ]]; then RPF_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then RPF_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then RPF_ARGS+=(--workspace "$WORKSPACE"); fi
if [[ "$STRICT" -eq 1 ]]; then RPF_ARGS+=(--strict); fi
"$SCRIPT_DIR/rpflow.sh" "${RPF_ARGS[@]}" >/dev/null

if [[ "$NO_CHAT" -eq 1 ]]; then
  echo "Agent-safe setup complete. Context exported to: $OUT" >&2
  echo "Prompt policy set. Start the agent manually when ready." >&2
  exit 0
fi

# 3) Start new Agent Mode run with the policy prompt already set on the tab
CHAT_JSON="$(MODEL_ID="$MODEL_ID" WORKFLOW_NAME="$WORKFLOW_NAME" CHAT_NAME="$CHAT_NAME" python3 - <<'PY'
import json, os
payload = {
  "op": "start",
  "message": "Use the current tab prompt and context artifacts for this run.",
  "session_name": os.environ["CHAT_NAME"],
  "timeout": 300,
}
model_id = os.environ.get("MODEL_ID", "").strip()
workflow_name = os.environ.get("WORKFLOW_NAME", "").strip()
if model_id:
  payload["model_id"] = model_id
if workflow_name:
  payload["workflow_name"] = workflow_name
print(json.dumps(payload))
PY
)"

CHAT_ARGS=(call --profile "$PROFILE" --tool agent_run --json-arg "$CHAT_JSON")
if [[ -n "$WINDOW" ]]; then CHAT_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then CHAT_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then CHAT_ARGS+=(--workspace "$WORKSPACE"); fi
if [[ "$STRICT" -eq 1 ]]; then CHAT_ARGS+=(--strict); fi

"$SCRIPT_DIR/rpflow.sh" "${CHAT_ARGS[@]}"

echo "Agent-safe run complete. Context export: $OUT" >&2
