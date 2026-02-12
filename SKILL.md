---
name: repoprompt
description: Automate Repo Prompt (rpflow + MCP + Agent Mode) for context building, file selection, chat_send, edits, and exports. Use for any repository planning/reading/searching/editing/refactor/review workflow; prefer rpflow for stable deterministic routing and use Repo Prompt Agent for interactive coding loops.
metadata: {"clawdbot": {"permissions": ["filesystem:/Users", "mcp"]}}
---

# Repo Prompt Automation (rpflow + rp-cli)

Use this skill when you need to drive the Repo Prompt macOS app programmatically for repo tasks.

## Prereqs / Assumptions

- Repo Prompt app is running.
- In Repo Prompt: Settings → MCP Server → MCP Server enabled.
- rp-cli is installed to PATH (Repo Prompt can install it via Settings → MCP Server → Install CLI to PATH).
- MCP connections require user approval and tool access control in Repo Prompt.

## Local defaults (this machine)

- Default repo base folder: $HOME/Documents/github
- Default Repo Prompt workspace name: GitHub
- Default compose tab (for automation): T1
- Window selection: with one window, -w is optional; set RP_WINDOW (or pass -w) when multiple windows are open
- Preferred orchestrator repo: $HOME/Documents/github/repoprompt-rpflow-cli

Environment overrides:
- RP_WORKSPACE (default: GitHub)
- RP_TAB (default: T1)
- RP_WINDOW (optional, required if multiple windows are open)
- RP_PROFILE (default: normal; used by scripts/rpflow.sh when --profile is omitted)

## Preferred interface on this machine: rpflow

For repeatable automation, use rpflow first and raw rp-cli second.

From $HOME/Documents/github/repoprompt-rpflow-cli:

```bash
# Basic health
PYTHONPATH=src python3 -m rpflow.cli doctor
PYTHONPATH=src python3 -m rpflow.cli smoke --workspace GitHub --tab T1

# Exec mode
PYTHONPATH=src python3 -m rpflow.cli exec --workspace GitHub --tab T1 -e 'tabs'

# Direct tool calls (-c/-j, including @file and @-)
PYTHONPATH=src python3 -m rpflow.cli call --workspace GitHub --tab T1 --tool apply_edits --json-arg @edits.json

# Export helpers
PYTHONPATH=src python3 -m rpflow.cli export --workspace GitHub --tab T1 --select-set repo/src/,repo/README.md --out /tmp/context.md
PYTHONPATH=src python3 -m rpflow.cli plan-export --workspace GitHub --tab T1 --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --fallback-export-on-timeout
PYTHONPATH=src python3 -m rpflow.cli autopilot --workspace GitHub --tab T1 --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --fallback-export-on-timeout

# Optional reliability/audit knobs
PYTHONPATH=src python3 -m rpflow.cli autopilot --workspace GitHub --tab T1 --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --report-json /tmp/rpflow-run.json
PYTHONPATH=src python3 -m rpflow.cli plan-export --workspace GitHub --tab T1 --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --resume-from-export /tmp/last-known-good.md
PYTHONPATH=src python3 -m rpflow.cli autopilot --workspace GitHub --tab T1 --profile fast --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --retry-on-timeout --fallback-export-on-timeout
bash "$HOME/clawd/skills/repoprompt/scripts/report-summary.sh" /tmp/rpflow-run.json

# Deterministic runs (CI-like): explicit routing required
PYTHONPATH=src python3 -m rpflow.cli exec --strict --window 1 --tab T1 --workspace GitHub -e 'tabs'

# Agent-safe kickoff wrapper (Repo Prompt 2.0)
bash "$HOME/clawd/skills/repoprompt/scripts/agent-safe.sh" \
  --workspace GitHub --tab T1 \
  --select-set "repo/src/,repo/README.md" \
  --task "Implement feature X with a safe edit plan" \
  --out /tmp/rp-agent-safe.md \
  --reasoning medium --mode plan
```

## Repo Prompt 2.0 integration (Agent Mode)

Use a hybrid operating model:
- rpflow first: deterministic routing, context curation, plan/export artifacts.
- Repo Prompt Agent second: interactive implementation/refactor loops in-app.

Recommended Agent defaults on this machine:
- Provider: Codex first (native integration), Claude Code/Gemini as fallback (beta caveats).
- Reasoning effort: low for quick scans, medium default, high for multi-file or architecture-heavy work.
- Tool preferences: keep write-capable tools constrained to task scope.
- Approval/edit review: enable for risky, broad, or potentially destructive edits.
- Session handling: prefer resumable threads; keep rpflow exports as reproducible source of truth.

## Key concepts

- Selection is context: Repo Prompt chat/tools operate on current selection.
- Selection modes: full, slices, codemap_only.
- Context Builder: automatic discovery and planning for larger/ambiguous repos.
- Multi-root workspaces: analyze multiple repos in one context.
- CLI Providers: use existing subscriptions without extra API setup.

## Recommended operating pattern (Repo Prompt first)

For any repo request (debugging, feature work, refactor, PR review):
1) Ensure routing is healthy (`rpflow smoke` or `scripts/preflight.sh`).
2) Switch to the right workspace/tab.
3) Build a tight selection (folders/files/slices/codemap_only).
4) Use builder for discovery/plan/review when needed.
5) Export prompt/context for reproducibility.
6) Choose execution lane:
   - Deterministic lane: apply structured edits via `apply_edits` / `file_actions`.
   - Interactive lane: open Repo Prompt Agent (Codex preferred), set reasoning/tool/approval policy, and iterate in-session.
7) For high-risk changes, require edit review before apply.
8) Keep final prompt/export artifacts for auditability and handoff.

## Raw rp-cli recipes (debug/direct use)

```bash
# Discover windows/tabs
rp-cli -e 'windows'
rp-cli -w 1 -e 'tabs'

# Workspace + selection + export
rp-cli -w 1 -t T1 -e 'workspace switch GitHub && select set repo/src/ && prompt export /tmp/context.md'

# Tool schemas and JSON arg support
rp-cli --tools-schema
rp-cli -e 'tools --schema'
rp-cli -w 1 -t T1 -c apply_edits -j @edits.json
cat edits.json | rp-cli -w 1 -t T1 -c apply_edits -j @-
```

## Timeout / fallback policy

- Context Builder can occasionally stall.
- Use `--profile fast|normal|deep` to match run urgency and context size.
- Prefer `rpflow autopilot --fallback-export-on-timeout --retry-on-timeout` (or `plan-export`) to still produce a usable export.
- For auditability, add `--report-json /path/report.json` on critical runs.
- Optional: use `--resume-from-export /tmp/last-known-good.md` for degraded recovery.
- Treat timeout as a normal operational state, not a silent success.

## Agent Mode caveats (2.0)

- Claude Code/Gemini agent sessions are beta; prefer Codex for longer or mission-critical runs.
- Keep long-running agent sessions checkpointed with periodic exports.
- For sensitive branches or broad edits, turn on edit review and keep a single writer.

## Workspace docs integration (AGENTS/MEMORY/TOOLS)

If you want this skill to be first-class in an OpenClaw workspace, keep these minimal snippets:
- AGENTS.md: use rpflow first for repo tasks; run `rpflow smoke --profile fast --report-json /tmp/rpflow-smoke.json` before major automation; then use Repo Prompt Agent for interactive loops when needed.
- MEMORY.md: default `--profile normal`; for builder flows prefer `--retry-on-timeout --fallback-export-on-timeout`; add `--report-json`, optional `--resume-from-export`; record Agent defaults (Codex-first + reasoning/edit-review policy).
- TOOLS.md: set `RP_PROFILE` default, document Agent Mode defaults, and use `scripts/report-summary.sh /tmp/rpflow-*.json` for triage.

## Scripts in this skill

- scripts/rpflow.sh: convenience wrapper for rpflow with default workspace/tab injection.
- scripts/preflight.sh: rpflow-based routing health check (smoke).
- scripts/rp.sh: rpflow exec wrapper.
- scripts/export-prompt.sh: rpflow export wrapper.
- scripts/plan-export.sh: rpflow autopilot wrapper (preflight + plan-export + fallback).
- scripts/context-flow.sh: end-to-end flow with codemap/slices via rpflow exec.
- scripts/agent-safe.sh: preflight + plan-export + safety prompt + new Agent chat kickoff (Codex-first policy wrapper).
- scripts/report-summary.sh: concise reader for rpflow --report-json outputs.
- scripts/bootstrap-github.sh: one-time workspace bootstrap (raw rp-cli exception for first-time workspace creation).

Use scripts when you want lightweight shell wrappers. Use rpflow for standardized orchestration.

## Coding-agent handoff

When implementation is delegated to another coding agent:
1) Generate a plan/context export first.
2) Run the coding agent in repo root with that export as source of truth.
3) Prefer structured multi-file edits via Repo Prompt tool calls where possible.
