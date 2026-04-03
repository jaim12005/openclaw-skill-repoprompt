#!/usr/bin/env bash
set -euo pipefail

WINDOW=""
TAB=""
WORKSPACE=""
BIND_PATH=""
SELECT_SET=""
CODEMAP_SET=""
TASK="Review the current changes for correctness, risk, regressions, and missing tests. Focus on real issues, not generic style chatter."
OUT=""
COPY_PRESET="${RP_REVIEW_COPY_PRESET:-codeReview}"
PROFILE="${RP_PROFILE:-normal}"
PREFLIGHT_REPORT_JSON=""
SCOPE="both"
STRICT=0
SLICE_SPECS=()

DEFAULT_WINDOW="${RP_WINDOW:-}"
DEFAULT_WORKSPACE="${RP_WORKSPACE:-}"
DEFAULT_TAB="${RP_TAB:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  review-current-changes.sh [-w WINDOW_ID] [-t TAB] [--workspace NAME] [--bind REPO_DIR]
                            [--select-set PATHS] --out FILE
                            [--scope worktree|staged|both] [--task TEXT]
                            [--codemap PATHS] [--slice SPEC] [--copy-preset PRESET]
                            [--profile fast|normal|deep] [--preflight-report-json FILE] [--strict]

Notes:
  - If --select-set is omitted, the script auto-detects changed files from the routed repo
    (or the current git repo) using the chosen scope.
  - --scope defaults to both (staged + unstaged + untracked)
  - --copy-preset defaults to codeReview
  - --slice format: path:start-end[:description]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window) WINDOW="$2"; shift 2 ;;
    -t|--tab) TAB="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --bind|--path|--repo) BIND_PATH="$2"; shift 2 ;;
    --select-set) SELECT_SET="$2"; shift 2 ;;
    --codemap) CODEMAP_SET="$2"; shift 2 ;;
    --slice) SLICE_SPECS+=("$2"); shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --copy-preset) COPY_PRESET="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --preflight-report-json) PREFLIGHT_REPORT_JSON="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$WINDOW" ]]; then WINDOW="$DEFAULT_WINDOW"; fi
if [[ -z "$TAB" ]]; then TAB="$DEFAULT_TAB"; fi
if [[ -z "$WORKSPACE" ]]; then WORKSPACE="$DEFAULT_WORKSPACE"; fi

if [[ -z "$OUT" ]]; then
  echo "Missing required --out" >&2
  usage
  exit 2
fi

case "$PROFILE" in
  fast|normal|deep) ;;
  *) echo "Invalid --profile: $PROFILE (use fast|normal|deep)" >&2; exit 2 ;;
esac

case "$SCOPE" in
  worktree|staged|both) ;;
  *) echo "Invalid --scope: $SCOPE (use worktree|staged|both)" >&2; exit 2 ;;
esac

resolve_repo_root() {
  local candidate="$1"
  REPO_CANDIDATE="$candidate" python3 - <<'PY'
import os, subprocess
candidate = os.environ.get('REPO_CANDIDATE', '').strip() or '.'
out = subprocess.run(
    ['git', '-C', candidate, 'rev-parse', '--show-toplevel'],
    text=True,
    capture_output=True,
)
if out.returncode != 0:
    raise SystemExit(out.stderr.strip() or f'Not a git repo: {candidate}')
print(out.stdout.strip())
PY
}

AUTO_REPO_ROOT=""
if [[ -n "$BIND_PATH" ]]; then
  AUTO_REPO_ROOT="$(resolve_repo_root "$BIND_PATH")"
else
  if git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
    AUTO_REPO_ROOT="$(resolve_repo_root "$PWD")"
    BIND_PATH="$AUTO_REPO_ROOT"
  fi
fi

if [[ -z "$SELECT_SET" ]]; then
  if [[ -z "$AUTO_REPO_ROOT" ]]; then
    echo "--select-set is required when no git repo/bind path is available for changed-file detection" >&2
    exit 2
  fi

  SELECT_SET="$(REPO_ROOT="$AUTO_REPO_ROOT" SCOPE="$SCOPE" python3 - <<'PY'
import os, subprocess
repo = os.environ['REPO_ROOT']
scope = os.environ['SCOPE']
commands = []
if scope in ('worktree', 'both'):
    commands.append(['git', '-C', repo, 'diff', '--name-only', '--diff-filter=ACMRTUXB'])
    commands.append(['git', '-C', repo, 'ls-files', '--others', '--exclude-standard'])
if scope in ('staged', 'both'):
    commands.append(['git', '-C', repo, 'diff', '--cached', '--name-only', '--diff-filter=ACMRTUXB'])
seen = []
for cmd in commands:
    out = subprocess.run(cmd, text=True, capture_output=True, check=True).stdout.splitlines()
    for line in out:
        path = line.strip()
        if path and path not in seen:
            seen.append(path)
print(','.join(seen))
PY
)"

  if [[ -z "$SELECT_SET" ]]; then
    echo "No changed files detected for review (scope=$SCOPE)" >&2
    exit 1
  fi
fi

FLOW_ARGS=(--select-set "$SELECT_SET" --task "$TASK" --builder-type review --out "$OUT" --profile "$PROFILE")
if [[ -n "$WINDOW" ]]; then FLOW_ARGS+=(--window "$WINDOW"); fi
if [[ -n "$TAB" ]]; then FLOW_ARGS+=(--tab "$TAB"); fi
if [[ -n "$WORKSPACE" ]]; then FLOW_ARGS+=(--workspace "$WORKSPACE"); fi
if [[ -n "$BIND_PATH" ]]; then FLOW_ARGS+=(--bind "$BIND_PATH"); fi
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
echo "Review artifact exported to: $OUT" >&2
