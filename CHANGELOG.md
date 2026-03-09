# Changelog

## 2026-03-09
- Replaced stale `$HOME/clawd/...` wrapper paths with the live `~/.openclaw/workspace/...` equivalents.
- Updated workflow/docs to explain the real workspace strategy: use `GitHub` for repos under `~/Documents/github`, and dedicated Repo Prompt workspaces for repos under `~/.openclaw/workspace` / `skills/`.
- Refreshed examples to use `OpenClawWorkspace`, `RepoPromptSkill`, and `RPFlowCLI` where appropriate.

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
