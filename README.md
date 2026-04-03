# OpenClaw Skill: repoprompt

## Overview
Automate Repo Prompt for repo discovery, context building, prompt exports, code review, Agent Mode, and multi-root workspace analysis.

Current stance:
- MCP-native Repo Prompt tools are the primary interface
- raw `rp-cli` is the direct shell bridge into those MCP tools
- `rpflow` is now the optional deterministic shell companion for retries, reports, exports, and scripted flows
- Agent Mode runs should use the modern `agent_manage` / `agent_run` surface

## Requirements
- OpenClaw 2026.2.x (or newer in same compatibility band)
- macOS (Repo Prompt app; Repo Prompt is currently macOS-only)
- python3
- Repo Prompt app running
- MCP Server enabled in Repo Prompt settings
- rp-cli on PATH
- rpflow repo available at $HOME/Documents/github/repoprompt-rpflow-cli

Quick launch helpers:
- `open -a "Repo Prompt" /path/to/folder`
- `open "repoprompt://open?path=/path/to/folder"`

Feature gating worth knowing:
- MCP Server, Agent Mode, Context Builder, and Codemaps are Repo Prompt Pro features
- file selection/workspaces, own API keys, and CLI Providers are available more broadly

Optional env defaults:
- RP_WORKSPACE, RP_TAB, RP_WINDOW
- RP_PROFILE (fast|normal|deep; default normal)
- RP_AGENT_MODEL_ID (for `agent-safe.sh`; default `engineer`)

Routing strategy on this machine:
- Prefer Repo Prompt binding by working directory via `bind_context`
- Let Repo Prompt's active binding/tab/workspace drive routing unless you intentionally pin RP_WORKSPACE / RP_TAB / RP_WINDOW
- Do not assume `GitHub` / `T1` unless you explicitly want those

## Recommended defaults
- MCP-first for normal work: `bind_context`, `manage_selection`, `context_builder`, `workspace_context`, `oracle_send`, `agent_manage`, `agent_run`
- Provider: Codex-first agent routing; use Repo Prompt role labels like `engineer` / `pair` unless you need a concrete model_id
- Reasoning effort: low (quick scans), medium (default), high (complex multi-file work)
- Approval/edit review: enable for risky/destructive/broad edits
- Artifact discipline: use rpflow exports only when you actually need a reproducible shell artifact

## High-value current features to actually use
- Context Builder is a two-stage system: discovery agent first, analysis model second
- Oracle Chat lets agents ask grounded repo questions mid-session
- Agent Mode sessions are per-tab, so parallel tasks can stay isolated
- Built-in workflows matter: `Plan & Build`, `Review`, `Refactor`, `Investigate`, `ChatGPT Export`
- Workflow protocols are the point: they separate discovery from implementation so the agent's reasoning budget is spent on the solution instead of orientation noise
- Some MCP clients expose workflow skills like `/rp-build`, `/rp-review`, `/rp-refactor`, `/rp-investigate`, `/rp-oracle-export`
- Codemaps are tree-sitter-backed signatures and are the reason Repo Prompt can include dramatically more reference files at sane token cost
- Multi-root workspaces are first-class and matter for monorepos, microservices, and adjacent repos
- Optional edit review is real and should stay on for risky work
- CLI Providers mean Repo Prompt can often use existing Claude / ChatGPT / Google subscriptions
- Repo Prompt is useful for more than code: any file-heavy workflow where context precision matters can benefit

## Repo Prompt skills are not OpenClaw skills
Repo Prompt's slash skills are separate from OpenClaw skills.
They are on-disk markdown templates for Agent Mode and terminal agents, discovered from provider-specific folders like `.claude/skills`, `.claude/commands`, `.agents/skills`, and `.agents/slash`.
Use them when you want Repo Prompt-native reusable workflows like `/rp-build` or your own custom templates.

## MCP server quick realities
- setup/approval happens in Repo Prompt, not rpflow
- if a client shows 0 tools right after setup, restart it so it refreshes the tool list
- only one Repo Prompt window owns the MCP server at a time
- advanced tools like `agent_run` / `agent_manage` can be policy-gated on some connections
- Repo Prompt is the local control plane; rpflow is just the shell helper downstream of that

## Agent Mode provider reality
- Codex CLI is the recommended Agent Mode provider
- Claude Code is full-featured and integrates deeply with MCP
- Claude Code GLM is available when a Z.AI API key is configured in Repo Prompt settings
- Gemini CLI is still beta and currently lacks some Agent Mode capabilities like compaction and bash-tool parity
- first-time provider setup/testing belongs in the Repo Prompt app settings/onboarding flow, not rpflow

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

# 3) Ask a grounded repo question mid-session when useful
rp-cli -c oracle_send -j '{"message":"What code path actually performs login?","mode":"plan"}'

# 4) Export only if you need an artifact
rp-cli -c workspace_context -j '{"op":"export","path":"/tmp/repo-context.md","copy_preset":"mcpBuilder"}'

# 5) Use rpflow when you want shell-level reliability helpers
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
