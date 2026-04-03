# OpenClaw Skill: repoprompt

## Overview
Automate Repo Prompt for repo discovery, context building, prompt exports, code review, and Agent Mode.

Current stance:
- MCP-native Repo Prompt tools are the primary interface
- raw `rp-cli` is the direct shell bridge into those MCP tools
- `rpflow` is now the optional deterministic shell companion for retries, reports, exports, and scripted flows
- Agent Mode runs should use the modern `agent_manage` / `agent_run` surface

## Requirements
- OpenClaw 2026.2.x (or newer in same compatibility band)
- macOS (Repo Prompt app)
- python3
- Repo Prompt app running
- MCP Server enabled in Repo Prompt settings
- rp-cli on PATH
- rpflow repo available at $HOME/Documents/github/repoprompt-rpflow-cli

Optional env defaults:
- RP_WORKSPACE, RP_TAB, RP_WINDOW
- RP_PROFILE (fast|normal|deep; default normal)
- RP_AGENT_MODEL_ID (for `agent-safe.sh`; default `engineer`)

Routing strategy on this machine:
- Prefer Repo Prompt binding by working directory via `bind_context`
- Let Repo Prompt's active binding/tab/workspace drive routing unless you intentionally pin RP_WORKSPACE / RP_TAB / RP_WINDOW
- Do not assume `GitHub` / `T1` unless you explicitly want those

## Recommended defaults
- MCP-first for normal work: `bind_context`, `manage_selection`, `context_builder`, `workspace_context`, `agent_manage`, `agent_run`
- Provider: Codex-first agent routing; use Repo Prompt role labels like `engineer` / `pair` unless you need a concrete model_id
- Reasoning effort: low (quick scans), medium (default), high (complex multi-file work)
- Approval/edit review: enable for risky/destructive/broad edits
- Artifact discipline: use rpflow exports only when you actually need a reproducible shell artifact

## Install (OpenClaw)
1) Clone this repo into `~/.openclaw/workspace/skills/repoprompt` for workspace-local install, or `~/.openclaw/skills/repoprompt` for shared install.
2) Enable MCP Server in Repo Prompt and install rp-cli to PATH.
3) Ensure the rpflow repo exists at `$HOME/Documents/github/repoprompt-rpflow-cli` (or set `RPFLOW_REPO`).
4) Start a new session after install so the skill is available in fresh context.

## Quick sanity checks
```bash
bash scripts/smoke.sh
bash scripts/smoke.sh --offline
rp-cli --raw-json -e 'windows'
rp-cli -c agent_manage -j '{"op":"list_workflows"}'
```

## 2-minute quickstart

```bash
# 1) Bind Repo Prompt to the repo you actually care about
rp-cli -c bind_context -j '{
  "op":"bind",
  "working_dirs":["/absolute/path/to/repo"],
  "create_if_missing":true
}'

# 2) Build context with MCP-native tools
rp-cli -c manage_selection -j '{"op":"clear"}'
rp-cli -c manage_selection -j '{"op":"add","paths":["src/","README.md"]}'
rp-cli -c context_builder -j '{"instructions":"<task>draft plan</task>","response_type":"plan"}'

# 3) Export only if you need an artifact
rp-cli -c workspace_context -j '{"op":"export","path":"/tmp/repo-context.md","copy_preset":"mcpBuilder"}'

# 4) Use rpflow when you want shell-level reliability helpers
./scripts/rpflow.sh autopilot \
  --profile fast \
  --select-set repo/src/ \
  --task "draft plan" \
  --out /tmp/rpflow-plan.md \
  --retry-on-timeout \
  --fallback-export-on-timeout \
  --report-json /tmp/rpflow-plan.json
```

## Usage
See SKILL.md for the MCP-first operating model and the narrower role rpflow now plays.

Useful wrappers:
- `./scripts/rpflow.sh smoke`
- `./scripts/rpflow.sh exec --raw-json -e 'windows'`
- `./scripts/rpflow.sh autopilot --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --fallback-export-on-timeout`
- `./scripts/rpflow.sh autopilot --profile fast --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --retry-on-timeout --fallback-export-on-timeout`
- `./scripts/agent-safe.sh --select-set "repo/src/" --task "implement X safely" --out /tmp/rp-agent-safe.md --reasoning medium --mode plan`
- `./scripts/report-summary.sh /tmp/rpflow-*.json`

## Suggested AGENTS.md / MEMORY.md / TOOLS.md snippets

Add these minimal lines in your OpenClaw workspace docs if you want MCP-first Repo Prompt behavior with rpflow available for shell automation.

AGENTS.md (repo rule):
- Use Repo Prompt MCP-native flows first for repo planning/reading/searching/editing tasks; use rpflow for shell automation and exported artifacts.
- Run `PYTHONPATH=src python3 -m rpflow.cli smoke --profile fast --report-json /tmp/rpflow-smoke.json` before major rpflow automation.
- After export, use Repo Prompt Agent Mode when useful; keep edit review on for risky writes.

MEMORY.md (long-term defaults):
- Default repo profile: `--profile normal`; use `fast` for quick checks and `deep` for large/complex runs.
- For builder flows prefer `--retry-on-timeout --fallback-export-on-timeout`; add `--report-json` and optionally `--resume-from-export`.
- Record Agent defaults (Codex-first + reasoning effort + approval/edit-review policy).

TOOLS.md (operator runbook):
- Set `RP_PROFILE=normal` (or `fast`/`deep`) for wrapper defaults.
- Add Repo Prompt 2.0 Agent defaults (provider, reasoning, approval policy).
- Use `./scripts/report-summary.sh /tmp/rpflow-*.json` to triage failures quickly.

## Agent-safe wrapper (new)
- `scripts/agent-safe.sh` is a one-command wrapper for Repo Prompt Agent Mode sessions.
- It runs preflight + plan-export (retry/fallback), sets a safety policy prompt, and optionally starts a new Agent Mode run.
- Defaults: Codex-first `engineer` routing, reasoning `medium`, mode `plan`.

## Troubleshooting
- `rp-cli not found in PATH`
  - Install from Repo Prompt MCP settings.
- tab/window routing errors
  - Run `scripts/preflight.sh` first (auto-selects when exactly one window exists).
  - If multiple windows are open, set `-w <window_id>` or `RP_WINDOW`.
  - Run `rpflow.sh exec -e 'tabs'` and target valid tab/window.
- builder stalls/timeouts
  - Use profile+retry+fallback, and optionally `--resume-from-export`.
- agent session instability (2.0)
  - Prefer Codex for long sessions; treat Claude/Gemini as beta.
  - Keep periodic exports/checkpoints and require edit review for risky changes.

## Security and privacy
- No secrets are committed by this skill.
- rpflow report JSON can include output tails; treat reports as local diagnostics.
- Runtime state files should stay local/ignored unless explicitly required.
- Public-share check: repository content is path-generalized and contains no API keys/tokens/passwords.

## License
MIT (see LICENSE).

## Sources
See SOURCES.md.
