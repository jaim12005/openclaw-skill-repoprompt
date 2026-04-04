# OpenClaw Skill: repoprompt

## Overview
Automate Repo Prompt for repo discovery, context building, prompt exports, code review, Agent Mode, IDE Mode manual workflows, and multi-root workspace analysis.

Current stance:
- MCP-native Repo Prompt tools are the primary interface
- raw `rp-cli` is the direct shell bridge / proxy client into those Repo Prompt tools
- `rpflow` is now the optional deterministic shell companion for retries, reports, exports, and scripted flows
- Agent Mode runs should use the modern `agent_manage` / `agent_run` surface

## Requirements
- OpenClaw 2026.2.x (or newer in same compatibility band)
- macOS (Repo Prompt app; Repo Prompt is currently macOS-only)
- python3
- Repo Prompt app running
- MCP Server enabled in Repo Prompt settings
- rp-cli on PATH
- rpflow repo available at $HOME/.hermes/vendor/repoprompt-rpflow-cli

Setup/control-plane notes:
- install `rp-cli` from Repo Prompt settings when needed
- the MCP popover/dashboard is the primary place to enable the server, inspect connections, and manage tool availability
- Repo Prompt can install/copy MCP config for popular clients like Cursor, VS Code, Codex CLI, Gemini CLI, OpenCode, Claude Desktop, and Claude Code
- provider/model setup also lives there: direct API providers, CLI providers, OpenRouter, custom OpenAI-compatible providers, and OpenAI custom base URLs
- copy presets, chat presets, model presets, workspace presets, model overrides, and benchmark controls live in Repo Prompt settings, not rpflow
- copy presets shape exported/pasted prompt artifacts; chat presets shape in-app chat/oracle behavior
- if MCP chat model presets are disabled, `list_models` effectively collapses to the current default model; if presets are enabled but empty, Repo Prompt uses its configured fallback model
- Background Mode can keep Repo Prompt alive after you close windows, so closed windows do not necessarily mean the app/server stopped
- MCP `context_builder` runs can open a fresh compose tab per discovery job, so automation should not assume the active tab count stays fixed
- `rp-cli` still requires the Repo Prompt app running with MCP Server enabled; it is a lighter shell access path, not a separate backend

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
- Use `rp-cli` when shell/on-demand access is enough and you do not want a full persistent MCP binding
- In `rp-cli`, use exec mode (`-e`) for quick human/agent work and raw JSON (`-c ... -j ...`) for deterministic automation
- Provider: Codex-first agent routing; use Repo Prompt role labels like `engineer` / `pair` unless you need a concrete model_id
- Reasoning effort: low (quick scans), medium (default), high (complex multi-file work)
- Approval/edit review: enable for risky/destructive/broad edits
- Artifact discipline: use rpflow exports only when you actually need a reproducible shell artifact

## High-value current features to actually use
- IDE Mode is the manual-control lane: Compose, Chat, Apply, Review
- IDE workflows matter too: Copy & Paste, Built-in Chat, Architectural Planning, XML Pro Edit, Pair Programming
- Prompt anatomy matters: instructions + file tree + codemaps + selected full files + slices
- Context Builder is a two-stage system: discovery agent first, analysis model second
- `context_builder` response types matter: `clarify`, `plan`, `question`, `review`
- Oracle Chat lets agents ask grounded repo questions mid-session and works best as an ongoing conversation
- Agent Mode sessions are per-tab, so parallel tasks can stay isolated
- Built-in workflows matter: `Plan & Build`, `Review`, `Refactor`, `Investigate`, `ChatGPT Export`
- Workflow protocols are the point: they separate discovery from implementation so the agent's reasoning budget is spent on the solution instead of orientation noise
- Some MCP clients expose workflow skills like `/rp-build`, `/rp-review`, `/rp-refactor`, `/rp-investigate`, `/rp-oracle-export`
- In Claude Code, `/repo` is the quick discovery entrypoint for installed Repo Prompt commands
- Codemaps are tree-sitter-backed signatures and are the reason Repo Prompt can include dramatically more reference files at sane token cost
- Line slices and the real-time token counter are core IDE-mode tools, not trivia
- Copy presets matter: Standard, Plan, XML Edit / Pro Edit, MCP Builder, MCP Pair, MCP Agent, Diff Follow-up
- Git diff inclusion is a first-class prompt-building tool when you need recent-change context
- Review mode and `/rp-review` are high-value because they bring surrounding architecture into the review instead of staring at isolated diffs
- Multi-root workspaces are first-class and matter for monorepos, microservices, and adjacent repos
- Git worktrees and Jujutsu repos are supported too
- Optional edit review is real and should stay on for risky work
- CLI Providers mean Repo Prompt can often use existing Claude / ChatGPT / Google subscriptions
- OpenRouter is good for variety/occasional use; direct providers are usually better as the primary lane
- Custom providers and OpenAI-compatible endpoints make self-hosted/internal model setups viable
- Repo Prompt is useful for more than code: any file-heavy workflow where context precision matters can benefit
- Effective context matters more than advertised max context; codemaps/slices/refinement are how you stay sharp

## IDE workflow quick picks
- 1–2 files / quick question: Copy & Paste or Built-in Chat
- 3+ files / complex change: Architectural Planning first
- multi-file code changes with review: XML Pro Edit
- huge iterative tasks: Pair Programming
- reviewing changes before commit: Review / `/rp-review`
- hands-off automation: Agent Mode workflows

Helpful manual pattern:
- use Context Builder first for discovery-heavy work
- then manually refine the selection before planning, chat, export, or apply/review
- when continuing existing work, include diffs instead of re-dumping the whole world
- for review/debug work, be explicit about compare scope: uncommitted, staged, back:N, or branch-vs-branch

## Repo Prompt skills are not OpenClaw skills
Repo Prompt's slash skills are separate from OpenClaw skills.
They are on-disk markdown templates for Agent Mode and terminal agents, discovered from provider-specific folders like `.claude/skills`, `.claude/commands`, `.agents/skills`, and `.agents/slash`.
Use them when you want Repo Prompt-native reusable workflows like `/rp-build` or your own custom templates.
In Agent Mode, use either a workflow or a slash skill per message, not both.

## MCP server quick realities
- setup/approval happens in Repo Prompt, not rpflow
- use the MCP popover/dashboard for quick setup, auto-start, enabled tools, model presets, context-builder agent selection, and connection visibility
- if a client shows 0 tools right after setup, restart it so it refreshes the tool list
- the normal transport is local-only with no open TCP ports exposed
- per-user isolation is the expected security model for the socket/session path
- clients can reconnect automatically after temporary Repo Prompt restarts/outages
- only one Repo Prompt window owns the MCP server at a time
- advanced tools like `agent_run` / `agent_manage` can be policy-gated on some connections
- Repo Prompt is the local control plane; `rp-cli` is the lighter shell proxy into it; rpflow is the higher-level reliability wrapper downstream of that

Useful extra notes:
- `claude-rp` is a Repo Prompt wrapper for Claude Code that forces Claude through Repo Prompt's MCP tools instead of Claude's own file-operation tools
- selection is context: the tab's selected files are what Repo Prompt chat/agent flows actually see

## Agent Mode provider reality
- Codex CLI is the recommended Agent Mode provider
- Claude Code is full-featured and integrates deeply with MCP
- Claude Code GLM is available when a Z.AI API key is configured in Repo Prompt settings
- Gemini CLI is still beta and currently lacks some Agent Mode capabilities like compaction and bash-tool parity
- first-time provider setup/testing belongs in the Repo Prompt app settings/onboarding flow, not rpflow

## Install (Hermes migration)
1) Clone this repo into `~/.hermes/skills/openclaw/openclaw-repoprompt` for Hermes-local install.
2) Enable MCP Server in Repo Prompt and install rp-cli to PATH.
3) Ensure the rpflow repo exists at `$HOME/.hermes/vendor/repoprompt-rpflow-cli` (or set `RPFLOW_REPO`).
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

# 2) Quick shell-style usage via exec mode
rp-cli -e 'select set src/'
rp-cli -e 'select add file.swift:10-50'
rp-cli -e 'builder "find auth code"'
rp-cli -e 'chat "How does this work?"'
rp-cli -e 'plan "Design auth system"'
rp-cli -e 'git status'
rp-cli -e 'agent_manage op=list_workflows'
rp-cli -e 'workspace list'
rp-cli -e 'tabs create "Bugfix"'

# 3) Tool discovery/schema inspection is built in
rp-cli -l
rp-cli -l explore
rp-cli --tools-schema
rp-cli -d search

# 4) Multi-window routing becomes explicit when more than one window is open
rp-cli -e 'windows'
rp-cli -w 1 -e 'tabs'
rp-cli -w 1 -t "Feature Work" -e 'context'

# MCP-native alternative: bind once per session with manage_workspaces select_tab
# After direct MCP select_tab, later tool calls stay on that tab until you change it.
# Also remember: create/add-folder/delete-style workspace actions can require Repo Prompt approval based on risk.

# 5) Chaining and redirection are part of the appeal
rp-cli -e 'workspace MyProject && select set src/ && context --all'
rp-cli -e 'tree > /tmp/structure.txt'

# 6) Deterministic JSON-style usage for automation
rp-cli -c manage_selection -j '{"op":"clear"}'
rp-cli -c manage_selection -j '{"op":"add","paths":["src/","README.md"]}'
rp-cli -c context_builder -j '{"instructions":"<task>draft plan</task>","response_type":"plan"}'
rp-cli -c read_file -j args.json
echo '{"path":"/tmp/test.txt"}' | rp-cli -c read_file -j @-

# 7) Ask a grounded repo question mid-session when useful
rp-cli -c oracle_send -j '{"message":"What code path actually performs login?","mode":"plan"}'

# 8) Parameter styles are flexible
rp-cli -e 'search "TODO" --extensions .swift --context-lines 3'
rp-cli -e 'file_search pattern=TODO filter.extensions=[".swift"]'

# 8.5) Selection / prompt / chat-state helpers are worth knowing
rp-cli -c manage_selection -j '{"op":"preview","view":"files"}'
rp-cli -c manage_selection -j '{"op":"add","mode":"slices","slices":[{"path":"src/auth.ts","lines":"10-20,40"}]}'
rp-cli -c workspace_context -j '{"include":["prompt","selection","tree","tokens"]}'
rp-cli -c prompt -j '{"op":"list_presets"}'
rp-cli -c chats -j '{"action":"list","scope":"tab"}'
rp-cli -e 'models'

# 9) Workflow shorthand flags and script files exist too
rp-cli -w 1 -t MyTab --workspace MyProject --select-set src/ --export-prompt ~/out.md
rp-cli --exec-file ~/scripts/daily-export.rp

# 9.5) Manage workspaces/tabs directly when you need lifecycle control
rp-cli -c manage_workspaces -j '{"action":"list_tabs"}'
rp-cli -c manage_workspaces -j '{"action":"create_tab","name":"Bugfix","mode":"blank","bind":true}'
rp-cli -c manage_workspaces -j '{"action":"select_tab","tab":"Bugfix","focus":true}'

# 10) Chat semantics matter
rp-cli -e 'chat "Follow-up question"'
rp-cli -e 'chat "New topic" --new'
rp-cli -e 'plan "Continue planning" --continue'

# 11) Advanced agent control is there when policy allows it
rp-cli -c agent_manage -j '{"op":"list_sessions","limit":5}'
rp-cli -c agent_run -j '{"op":"wait","session_id":"<uuid>","timeout":10}'
rp-cli -c agent_run -j '{"op":"steer","session_id":"<uuid>","message":"Fix it","wait":true}'
# Native Agent Mode continuity tools like Session Handoff / Session History stay in Repo Prompt UI itself.

# 12) JSON-heavy edit/file actions stay clearer in call form
rp-cli -e 'call apply_edits {"path":"src/f.ts","search":"old","replace":"new"}'
rp-cli -e 'call file_actions {"action":"create","path":"src/new.ts"}'

# 13) Help is tiered
rp-cli --help
rp-cli --help-interactive
rp-cli --help-scripting
rp-cli --help-advanced

# 14) Interactive mode exists for exploration/debugging
rp-cli -i

# 15) Use rpflow when you want shell-level reliability helpers
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
- `./scripts/bind-repo.sh --path /absolute/path/to/repo`
- `./scripts/export-prompt.sh --bind /absolute/path/to/repo --select-set "README.md,scripts/" --copy-preset mcpBuilder --out /tmp/context.md`
- `./scripts/plan-task.sh --bind /absolute/path/to/repo --select-set "README.md,SKILL.md,scripts/" --task "Plan the wrapper cleanup" --out /tmp/plan.md`
- `./scripts/review-current-changes.sh --bind /absolute/path/to/repo --out /tmp/review.md`
- Thin Builder wrappers now default to slow-run handling: 300s timeout plus one retry and then context-only fallback export (`RP_BUILDER_TIMEOUT`, `RP_BUILDER_RETRY_ON_TIMEOUT`, `RP_BUILDER_RETRY_TIMEOUT`, `RP_BUILDER_RETRY_TIMEOUT_SCALE`, `RP_BUILDER_FALLBACK_ON_TIMEOUT`).
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
- Thin builder wrappers already default to retry + fallback export; override with `--no-retry-on-timeout` / `--no-fallback-export-on-timeout` when you want hard failure instead.
- For rpflow autopilot builder flows prefer `--retry-on-timeout --fallback-export-on-timeout`; add `--report-json` and optionally `--resume-from-export`.
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
- command hangs or an operation seems stuck waiting
  - Check Repo Prompt for an approval dialog first.
  - Confirm MCP Server is enabled and the app is actually still running.
- tab/window routing errors
  - Run `scripts/preflight.sh` first (auto-selects when exactly one window exists).
  - If multiple windows are open, set `-w <window_id>` or `RP_WINDOW`.
  - Run `rpflow.sh exec -e 'tabs'` and target valid tab/window.
- scripts that launch Repo Prompt and `rp-cli` together
  - Add a small server-readiness wait upstream before the CLI call (for example the CLI's `--wait-for-server 5` pattern).
- sandboxed shells cannot reach the Repo Prompt socket
  - Prefer direct MCP integration instead of shelling out to `rp-cli`.
  - If you must use Bash/CLI, run where local socket access is actually allowed.
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
