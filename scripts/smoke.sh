#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OFFLINE_ONLY=0
if [[ "${1:-}" == "--offline" ]]; then
  OFFLINE_ONLY=1
fi

echo "[1/4] shell syntax"
for f in scripts/*.sh; do
  bash -n "$f"
done

echo "[2/4] wrapper help"
for f in scripts/agent-safe.sh scripts/bind-repo.sh scripts/bootstrap-github.sh scripts/context-flow.sh scripts/export-prompt.sh scripts/plan-export.sh scripts/plan-task.sh scripts/preflight.sh scripts/report-summary.sh scripts/review-current-changes.sh scripts/rp.sh scripts/rpflow.sh; do
  echo "### $(basename "$f")"
  bash "$f" --help | sed -n '1,12p'
done

if [[ "$OFFLINE_ONLY" == "1" ]]; then
  echo "[3/4] offline mode"
  echo "Skipping live Repo Prompt/rpflow checks"
  echo "repoprompt_smoke=PASS"
  exit 0
fi

echo "[3/4] rpflow doctor"
bash scripts/rpflow.sh doctor | sed -n '1,40p'

echo "[4/4] rpflow preflight"
bash scripts/preflight.sh | sed -n '1,20p'

echo "repoprompt_smoke=PASS"
