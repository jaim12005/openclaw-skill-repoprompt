# OpenClaw Skill: repoprompt

## Overview
Automate Repo Prompt (rpflow + MCP + Agent Mode) for context building, file selection, chat_send, edits, and exports.

This skill is hybrid and rpflow-first:
- rpflow is the deterministic orchestration interface (routing, selection, exports)
- Repo Prompt Agent (2.0) is the interactive coding loop
- raw rp-cli is fallback/debug only
- most wrappers in scripts/ delegate to rpflow
- bootstrap-github.sh is the setup-time exception

## Requirements
- OpenClaw 2026.2.x (or newer in same compatibility band)
- Repo Prompt app running
- MCP Server enabled in Repo Prompt settings
- rp-cli on PATH
- rpflow repo available at $HOME/Documents/github/repoprompt-rpflow-cli

Optional env defaults:
- RP_WORKSPACE, RP_TAB, RP_WINDOW
- RP_PROFILE (fast|normal|deep; default normal)

## Repo Prompt 2.0 defaults (recommended)
- Provider: Codex first (native integration), Claude Code/Gemini fallback when needed.
- Reasoning effort: low (quick scans), medium (default), high (complex multi-file work).
- Approval/edit review: enable for risky/destructive/broad edits.
- Artifact discipline: keep rpflow exports as reproducible checkpoints for agent sessions.

## Install (OpenClaw)
1) Clone this repo into ~/clawd/skills/repoprompt (or ~/.openclaw/skills/repoprompt).
2) Enable MCP Server in Repo Prompt and install rp-cli to PATH.
3) Restart the OpenClaw gateway.

## 2-minute quickstart (community)

```bash
# 1) Smoke check
skills/repoprompt/scripts/rpflow.sh smoke --report-json /tmp/rpflow-smoke.json
# expected: tabs: ok / context: ok / tools-schema: ok

# 2) End-to-end plan/export
skills/repoprompt/scripts/rpflow.sh autopilot \
  --profile fast \
  --select-set repo/src/ \
  --task "draft plan" \
  --out /tmp/rpflow-plan.md \
  --retry-on-timeout \
  --fallback-export-on-timeout \
  --report-json /tmp/rpflow-plan.json

# 3) Read compact status
skills/repoprompt/scripts/report-summary.sh /tmp/rpflow-plan.json
```

## Usage
See SKILL.md for the hybrid operating model (rpflow deterministic + Agent interactive), command matrix, strict mode, timeout/fallback policy, and wrappers.

Useful wrappers:
- `skills/repoprompt/scripts/rpflow.sh smoke`
- `skills/repoprompt/scripts/rpflow.sh exec -e 'tabs'`
- `skills/repoprompt/scripts/rpflow.sh autopilot --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --fallback-export-on-timeout`
- `skills/repoprompt/scripts/rpflow.sh autopilot --profile fast --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --retry-on-timeout --fallback-export-on-timeout`
- `skills/repoprompt/scripts/agent-safe.sh --workspace GitHub --tab T1 --select-set "repo/src/" --task "implement X safely" --out /tmp/rp-agent-safe.md --reasoning medium --mode plan`
- `skills/repoprompt/scripts/report-summary.sh /tmp/rpflow-*.json`

## Suggested AGENTS.md / MEMORY.md / TOOLS.md snippets

Add these minimal lines in your OpenClaw workspace docs if you want rpflow-first repo automation behavior.

AGENTS.md (repo rule):
- Use Repo Prompt via rpflow first for any repo planning/reading/searching/editing task.
- Run `PYTHONPATH=src python3 -m rpflow.cli smoke --workspace GitHub --tab T1 --profile fast --report-json /tmp/rpflow-smoke.json` before major repo automation.
- After export, use Repo Prompt Agent (2.0) for interactive loops when useful; keep edit review on for risky writes.

MEMORY.md (long-term defaults):
- Default repo profile: `--profile normal`; use `fast` for quick checks and `deep` for large/complex runs.
- For builder flows prefer `--retry-on-timeout --fallback-export-on-timeout`; add `--report-json` and optionally `--resume-from-export`.
- Record Agent defaults (Codex-first + reasoning effort + approval/edit-review policy).

TOOLS.md (operator runbook):
- Set `RP_PROFILE=normal` (or `fast`/`deep`) for wrapper defaults.
- Add Repo Prompt 2.0 Agent defaults (provider, reasoning, approval policy).
- Use `skills/repoprompt/scripts/report-summary.sh /tmp/rpflow-*.json` to triage failures quickly.

## Agent-safe wrapper (new)
- `scripts/agent-safe.sh` is a one-command wrapper for Repo Prompt Agent 2.0 sessions.
- It runs preflight + plan-export (retry/fallback), sets a safety policy prompt, and optionally starts a new chat.
- Defaults: Codex-first model preset (`current_chat_model`), reasoning `medium`, mode `plan`.

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
