#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  report-summary.sh <report.json> [report2.json ...]

Examples:
  report-summary.sh /tmp/rpflow-run.json
  report-summary.sh /tmp/rpflow-*.json

Prints a concise summary for rpflow --report-json files.
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

python3 - "$@" <<'PY'
import json
import sys
from pathlib import Path


def yn(v):
    return "yes" if v else "no"

for i, arg in enumerate(sys.argv[1:], start=1):
    p = Path(arg).expanduser()
    print(f"=== {p} ===")
    if not p.exists():
        print("missing: file not found")
        continue
    try:
        obj = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"invalid json: {e}")
        continue

    cmd = obj.get("command", "?")
    ok = bool(obj.get("ok", False))
    code = obj.get("exit_code", "?")
    profile = obj.get("profile", "?")
    dur = obj.get("duration_ms", "?")
    route = obj.get("routing") or {}
    window = route.get("window", "?")
    tab = route.get("tab", "?")
    ws = route.get("workspace", "?")

    print(f"command: {cmd}")
    print(f"status: {'ok' if ok else 'fail'} (code={code})")
    print(f"profile: {profile}  duration_ms: {dur}")
    print(f"routing: window={window} tab={tab} workspace={ws}")

    timeout = obj.get("timeout_seconds")
    pto = obj.get("preflight_timeout_seconds")
    if timeout is not None or pto is not None:
        print(f"timeouts: timeout={timeout} preflight={pto}")

    print(
        "controls: "
        f"retry={yn(obj.get('retry_used'))} "
        f"fallback={yn(obj.get('fallback_used'))} "
        f"resume={yn(obj.get('resume_used'))}"
    )

    stages = obj.get("stages") or []
    bad = [s for s in stages if s.get("classification") not in {"ok", "workspace_already_selected"}]
    if bad:
        print("issues:")
        for s in bad:
            print(
                f"- {s.get('name')}: {s.get('classification')} "
                f"code={s.get('code')} timed_out={s.get('timed_out')} signal={s.get('signal')}"
            )
    else:
        print("issues: none")

    if i != len(sys.argv[1:]):
        print()
PY
