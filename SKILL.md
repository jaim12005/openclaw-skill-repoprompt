---
name: repoprompt
description: Use Repo Prompt for repository planning, discovery, review, and editing. Prefer MCP-native Repo Prompt tools first; use rpflow only for shell-based deterministic automation, report-json traces, timeout/retry/fallback exports, or wrapper-driven flows.
---

# Repo Prompt Automation

Repo Prompt is now best treated as MCP-first.

Use this skill when you want Repo Prompt to help with:
- repo discovery and context building
- targeted file selection and prompt exports
- code review and git-aware analysis
- agentic coding loops in Repo Prompt Agent Mode
- deterministic shell automation when an export/report/fallback artifact matters

## Rule of thumb

Use Repo Prompt in this order:

1. MCP-native Repo Prompt tools first
2. raw `rp-cli -c ... -j ...` second
3. `rpflow` third, only when you specifically want shell automation and reliability helpers

Bluntly: rpflow is no longer the center of gravity.
It is the shell companion.
The live product surface is MCP.

## What changed

Current Repo Prompt exposes rich MCP tools directly, including:
- `bind_context`
- `manage_workspaces`
- `manage_selection`
- `workspace_context`
- `context_builder`
- `prompt`
- `agent_manage`
- `agent_run`
- `file_search`
- `get_code_structure`
- `get_file_tree`
- `read_file`
- `git`
- `apply_edits`
- `file_actions`
- `oracle_send`
- `oracle_utils`

So do not default to old habits like:
- assuming workspace `GitHub`
- assuming tab `T1`
- forcing `workspace switch GitHub`
- treating `rpflow` as mandatory for every Repo Prompt action
- using the old `chat_send` naming when Agent Mode now lives behind `agent_run`

## Preferred MCP-first workflow

### 1) Bind to the right repo

Prefer binding by working directory instead of guessing a workspace name.

Raw `rp-cli` example:

```bash
rp-cli -c bind_context -j '{
  "op": "bind",
  "working_dirs": ["/absolute/path/to/repo"],
  "create_if_missing": true
}'
```

Use `bind_context` for routing.
Use `manage_workspaces` when you truly need workspace inventory or workspace lifecycle.

### 2) Build selection deliberately

Use:
- `manage_selection` for full files, codemap-only files, or slices
- `file_search`, `get_file_tree`, `get_code_structure`, and `read_file` for discovery
- `git` for diff/log/show/blame context

Examples:

```bash
rp-cli -c manage_selection -j '{"op":"clear"}'
rp-cli -c manage_selection -j '{"op":"add","paths":["src/","README.md"]}'
rp-cli -c manage_selection -j '{"op":"add","paths":["docs/"],"mode":"codemap_only"}'
rp-cli -c file_search -j '{"pattern":"auth","filter":{"paths":["src/"]}}'
rp-cli -c get_code_structure -j '{"paths":["src/auth/"]}'
```

### 3) Use Context Builder for discovery-heavy work

Context Builder is not just a convenience wrapper.
It is the core two-stage pipeline:
1. a discovery agent explores the repo and curates the relevant files
2. an analysis model turns that curated context into a plan, review, answer, or investigation result

Prefer `context_builder` over hand-rolled builder command strings when you want Repo Prompt to discover relevant files.

```bash
rp-cli -c context_builder -j '{
  "instructions": "<task>Trace the login flow</task><context>Need the real auth path and edge cases.</context>",
  "response_type": "plan"
}'
```

### 4) Export context or select a prompt preset

Use `workspace_context` and `prompt` for exports/presets.
Useful preset kinds include:
- `mcpBuilder`
- `mcpPlan`
- `mcpAgent`
- `mcpPair`
- `proEdit`
- `codeReview`
- `diffFollowUp`

Examples:

```bash
rp-cli -c prompt -j '{"op":"list_presets"}'
rp-cli -c prompt -j '{"op":"select_preset","preset":"mcpBuilder"}'
rp-cli -c workspace_context -j '{"op":"export","path":"/tmp/repo-context.md","copy_preset":"mcpBuilder"}'
```

### 5) Use Oracle Chat and Agent Mode intentionally

Oracle Chat is useful when you want to ask Repo Prompt questions about the codebase mid-session without manually rebuilding context yourself.
Use:
- `oracle_send` for the actual question / plan / review turn
- `oracle_utils` for models and session helpers

That is especially useful when an agent needs a second opinion or a grounded repo answer while already working.

Agent Mode now centers on:
- `agent_manage` for agent/model/workflow discovery and session management
- `agent_run` for start/poll/wait/steer/respond

Role labels you can pass as `model_id`:
- `explore`
- `engineer`
- `pair`
- `design`

Built-in workflows currently include:
- `Plan & Build`
- `Review`
- `Refactor`
- `Investigate`
- `ChatGPT Export`

These matter because they are not all the same thing:
- `Plan & Build` = Context Builder + plan + implementation
- `Review` = git-aware review with repo context
- `Refactor` = analyze first, then preserve behavior while restructuring
- `Investigate` = evidence-gathering until root cause is clear

Repo Prompt also exposes workflow-oriented slash-command style affordances in some MCP clients, such as `/rp-build`, `/rp-review`, and `/rp-investigate`.
Treat those as first-class current product behavior, not trivia.

Examples:

```bash
rp-cli -c agent_manage -j '{"op":"list_agents"}'
rp-cli -c agent_manage -j '{"op":"list_workflows"}'
rp-cli -c agent_run -j '{
  "op":"start",
  "model_id":"engineer",
  "workflow_name":"Plan & Build",
  "message":"Use the current selection and prompt to implement the task.",
  "timeout":300
}'
```

For follow-up turns on an existing Agent Mode session, use `agent_run` with `steer` or `respond`, not a fake new-chat flow.

Also remember:
- each compose tab effectively owns its own agent session context
- optional edit review is a real product feature and should stay enabled for risky work
- image support is part of interactive Agent Mode, not something rpflow should pretend to wrap
- session management and usage tracking live on the Agent Mode side, not in rpflow

## CLI providers and when rpflow is still worth using

Repo Prompt can use CLI-provider-backed models too.
That means Agent Mode, Chat Mode, and Context Builder can ride existing Claude / ChatGPT / Google subscriptions in supported setups instead of requiring separate API billing for everything.
That is product-important and worth documenting, but it does not change the core ordering here: MCP first, rpflow second.

Use `rpflow` when you need shell-friendly automation with:
- deterministic routing from scripts
- `--report-json` artifacts
- timeout profiles
- retry/fallback/resume behavior for large builder runs
- reproducible exported prompt files for handoff/audit

That makes rpflow a good fit for:
- unattended wrapper scripts
- CI-ish local automation
- repeatable `plan-export` / `autopilot` flows
- environments where you want one stable shell surface over changing Repo Prompt UI details

It is not required for ordinary MCP-driven Repo Prompt work.
And it should not try to become a bad clone of interactive Agent Mode features like per-tab sessions, Oracle questioning, image attachments, or workflow-driven agent UX.

## rpflow commands that still matter

From `/Users/clawdbot/Documents/github/repoprompt-rpflow-cli`:

```bash
python3 -m rpflow.cli doctor
python3 -m rpflow.cli smoke --profile fast
python3 -m rpflow.cli export --select-set repo/src/,repo/README.md --out /tmp/context.md
python3 -m rpflow.cli plan-export --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --retry-on-timeout --fallback-export-on-timeout
python3 -m rpflow.cli autopilot --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --report-json /tmp/rpflow.json --retry-on-timeout --fallback-export-on-timeout
python3 -m rpflow.cli call --tool apply_edits --json-arg @edits.json
```

Important: modern rpflow should follow the active Repo Prompt binding/workspace/tab when you do not explicitly pin them.
Do not hardcode `GitHub` / `T1` unless you actually mean it.

## Local defaults on this machine

- Repo Prompt orchestrator repo: `/Users/clawdbot/Documents/github/repoprompt-rpflow-cli`
- Skill repo: `/Users/clawdbot/.openclaw/workspace/skills/repoprompt`
- `rp-cli` is the direct bridge into Repo Prompt MCP tools
- `scripts/rpflow.sh` is the wrapper into the local rpflow repo

## Recommended operating pattern in OpenClaw

For repo work:
1. Bind Repo Prompt to the repo by working directory.
2. Use MCP-native Repo Prompt tools for discovery, selection, search, codemaps, git context, and agent sessions.
3. Export context only when you actually need an artifact.
4. Use rpflow wrappers only when a scripted/retriable/reportable shell flow is the goal.

## Wrappers in this skill

- `scripts/preflight.sh` — quick rpflow health check using current binding unless you pin routing
- `scripts/rpflow.sh` — wrapper into the local rpflow repo
- `scripts/rp.sh` — thin `rpflow exec` wrapper
- `scripts/export-prompt.sh` — selection → export helper
- `scripts/plan-export.sh` — autopilot wrapper for plan + export with retry/fallback
- `scripts/context-flow.sh` — curated context-building shell flow
- `scripts/agent-safe.sh` — safe Agent Mode kickoff wrapper using `agent_run`
- `scripts/report-summary.sh` — compact reader for rpflow JSON reports
- `scripts/bootstrap-github.sh` — older workspace bootstrap helper; only use when you truly need manual workspace setup

## Practical guidance

- Prefer `bind_context` over guessing window/workspace state.
- Prefer `context_builder` over giant manual file sets when discovery is the real problem.
- Prefer `agent_run`/`agent_manage` over older chat-oriented assumptions.
- Prefer prompt presets and `workspace_context export` over ad hoc copy/paste when you want a reproducible artifact.
- Keep one writer for risky edits.
- For destructive/broad changes, require review or approval in Repo Prompt Agent Mode.
