---
name: repoprompt
description: Automate Repo Prompt (MCP + rp-cli) for context building, file selection, chat_send, edits, and exports. Use for any repository planning/reading/searching/editing/refactor/review workflow; prefer rpflow for stable routing/timeouts and use raw rp-cli for direct debugging.
metadata: {"clawdbot": {"permissions": ["filesystem:$HOME/Documents/github", "mcp"]}}
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

# Deterministic runs (CI-like): explicit routing required
PYTHONPATH=src python3 -m rpflow.cli exec --strict --window 1 --tab T1 --workspace GitHub -e 'tabs'
```

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
6) Apply edits with JSON-first calls (`apply_edits` / `file_actions`) when possible.

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
- Prefer `rpflow plan-export --fallback-export-on-timeout` to still produce a usable export.
- Treat timeout as a normal operational state, not a silent success.

## Scripts in this skill

- scripts/rpflow.sh: convenience wrapper for rpflow with default workspace/tab injection.
- scripts/preflight.sh: validates Repo Prompt + MCP + routing.
- scripts/rp.sh: safe workspace switch + exec wrapper.
- scripts/export-prompt.sh: selection → prompt export.
- scripts/plan-export.sh: selection → builder plan → prompt export.
- scripts/context-flow.sh: end-to-end flow with codemap/slices.
- scripts/bootstrap-github.sh: ensure GitHub workspace points to $HOME/Documents/github.

Use scripts when you want lightweight shell wrappers. Use rpflow for standardized orchestration.

## Coding-agent handoff

When implementation is delegated to another coding agent:
1) Generate a plan/context export first.
2) Run the coding agent in repo root with that export as source of truth.
3) Prefer structured multi-file edits via Repo Prompt tool calls where possible.
