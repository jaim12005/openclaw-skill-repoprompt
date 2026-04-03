# Changelog

## 2026-04-03
- Repositioned the skill as MCP-first instead of rpflow-first.
- Rewrote `SKILL.md` around modern Repo Prompt surfaces: `bind_context`, `manage_workspaces`, `manage_selection`, `workspace_context`, `context_builder`, `agent_manage`, and `agent_run`.
- Updated docs/examples to stop assuming `GitHub` / `T1` as universal defaults.
- Updated wrapper defaults so omitted workspace/tab values defer to the active Repo Prompt binding/state.
- Updated `scripts/preflight.sh` to parse current raw `windows` JSON.
- Updated `scripts/agent-safe.sh` to kick off Agent Mode via MCP `agent_run` instead of the older `chat_send` flow.

## 2026-03-09
- Replaced stale `$HOME/clawd/...` wrapper paths with the live `~/.openclaw/workspace/...` equivalents.
- Updated workflow/docs to explain the real workspace strategy: use `GitHub` for repos under `~/Documents/github`, and dedicated Repo Prompt workspaces for repos under `~/.openclaw/workspace` / `skills/`.
- Refreshed examples to use `OpenClawWorkspace`, `RepoPromptSkill`, and `RPFlowCLI` where appropriate.
- Fixed `scripts/rpflow.sh` so zero-extra-arg commands like `rpflow.sh doctor` no longer fail under `set -u`.
- Added `--help` handling to wrappers that previously made accidental execution too easy (`rpflow.sh`, `bootstrap-github.sh`, `report-summary.sh`).
- Added `scripts/smoke.sh` plus offline-capable CI validation.
- Updated readiness/install docs to reflect current OpenClaw behavior and Repo Prompt prerequisites.
- Added profile/timeout/report/strict passthrough to preflight/plan-export/agent-safe wrappers.
- Made `scripts/context-flow.sh` export atomically so failed runs no longer delete the previous artifact first.
- Simplified `bootstrap-github.sh` to switch first and only create the workspace on a clear not-found failure.
- Normalized README examples to repo-local `./scripts/...` invocation paths.

## 2026-02-11
- Integrated Repo Prompt 2.0 guidance across skill docs.
- Added hybrid operating model: rpflow-first deterministic orchestration + Repo Prompt Agent interactive loops.
- Added Agent defaults (Codex-first provider, reasoning effort policy, edit-review/approval guidance).
- Updated WORKFLOW.md to include deterministic vs interactive execution lanes.
- Added `scripts/agent-safe.sh` one-command wrapper for Codex-first Agent Mode runs (preflight + plan-export + policy prompt + chat kickoff).

## 2026-02-02
- Initial standalone repository import.
- Added permissions metadata to SKILL.md.
- Removed legacy origin metadata.
