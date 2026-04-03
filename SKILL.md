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
- precise manual prompt building in IDE Mode
- multi-root workspace analysis across related repos/services
- non-code file/document exploration where precise context control still matters
- deterministic shell automation when an export/report/fallback artifact matters

Repo Prompt itself is macOS-only.
If the app is not open yet, useful launch patterns are:
- `open -a "Repo Prompt" /path/to/folder`
- `open "repoprompt://open?path=/path/to/folder"`

## Rule of thumb

Use Repo Prompt in this order:

1. MCP-native Repo Prompt tools first
2. raw `rp-cli -c ... -j ...` second
3. `rpflow` third, only when you specifically want shell automation and reliability helpers

Bluntly: rpflow is no longer the center of gravity.
It is the shell companion.
The live product surface is MCP.

That matters because Repo Prompt's workflows deliberately separate discovery from implementation.
The Context Builder spends the orientation budget finding the right code.
The agent then spends its reasoning budget solving the task instead of drowning in grep noise.

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

`rp-cli` matters too.
Think of it as the shell-facing proxy client for Repo Prompt's MCP surface.
It talks to the running Repo Prompt app over the local connection path, so shell-capable agents and scripts can use Repo Prompt tools without a full persistent MCP integration.
You still need Repo Prompt running with MCP Server enabled.

Important product constraints:
- MCP Server, Agent Mode, Context Builder, and Codemaps are Pro features
- file selection/workspaces, own API keys, and CLI Providers are available more broadly
- if a requested workflow depends on MCP/Agent/Context Builder/Codemaps, assume Pro is required unless the product docs say otherwise

Important setup/control-plane surfaces in Repo Prompt itself:
- the MCP popover/status dashboard is the primary place to enable the server, inspect status, manage clients, and adjust tool availability
- chat model presets control what `list_models` / MCP chat flows expose to clients
- the Context Builder agent setting controls whether Codex, Claude, or Gemini powers `context_builder`
- Repo Prompt can install/copy MCP config for popular clients directly from the UI
- provider setup also lives in Repo Prompt itself: direct API providers, CLI providers, OpenRouter, custom OpenAI-compatible providers, and OpenAI custom base URLs

Provider lane rule of thumb:
- direct API keys for your main production models when you want the cleanest native path
- CLI providers when you want to use existing subscriptions economically
- OpenRouter when you want model variety or occasional/fallback access
- custom providers for self-hosted, company-internal, proxy, or OpenAI-compatible endpoints

So do not default to old habits like:
- assuming workspace `GitHub`
- assuming tab `T1`
- forcing `workspace switch GitHub`
- treating `rpflow` as mandatory for every Repo Prompt action
- forgetting that `rp-cli` is a valid on-demand shell bridge when full MCP binding is overkill
- using the old `chat_send` naming when Agent Mode now lives behind `agent_run`

## IDE Mode still matters

Do not treat Repo Prompt as only an MCP/agent product.
IDE Mode is still the core manual lane when you want full control over context before involving a model.

The four IDE views matter operationally:
- Compose = build selection, write instructions, choose a copy preset
- Chat = talk to a model with selected context included automatically
- Apply = paste AI-generated edits for parsing
- Review = inspect/approve/reject diffs before applying

High-value IDE controls:
- full-file selection
- slices for precise line-range context
- codemaps for cheap structural context
- real-time token counting
- copy presets like Standard, Plan, XML Edit / Pro Edit, MCP Builder, MCP Pair, and MCP Agent

Prompt anatomy in practice:
- your instructions
- file tree / project structure
- codemaps for structural context
- selected full files
- slices from large files

Manual context building still matters:
- browse/select by hand when you already know the hot files
- use Context Builder for discovery-heavy tasks
- for complex tasks, start with Context Builder, then manually refine the selection before the next step

High-value IDE workflows:
- Copy & Paste = the simple lane for quick tasks and external web AIs
- Built-in Chat = interactive exploration/iteration with selected context already included
- Architectural Planning = plan first for 3+ file or system-shaping work
- XML Pro Edit = structured multi-file edits with Review before apply
- Pair Programming = large iterative work where a driver agent and Repo Prompt Chat split the job

That manual lane is often the right answer when you want careful context curation, external model copy/paste, or review before apply.
A blunt heuristic that matches the product docs pretty well:
- 1–2 files: Copy & Paste or Built-in Chat
- 3+ files / complex change: Architectural Planning first
- multi-file edit review: XML Pro Edit
- very large iterative work: Pair Programming
- fully automated: Agent Mode workflows

Useful supporting IDE controls:
- file tree modes like Auto / Full / Selected / None depending on how much structure the model needs
- git diff inclusion when the task depends on recent changes or ongoing feature work
- Diff Follow-up style review when you want a planning/review model to inspect what changed without resending the entire codebase
- filter/ignore tuning when needed so the tree actually shows the files you care about

## rp-cli vs direct MCP

Use `rp-cli` when:
- the agent has Bash/shell access but not native MCP support
- you want one-shot on-demand Repo Prompt access without loading MCP tool schemas into the whole session
- you want shell chaining, redirection, or mixed shell workflows
- formatted text output is good enough and lower overhead is useful

Use direct MCP when:
- the agent supports MCP natively
- persistent tab/window binding matters
- you want structured tool responses every turn
- Repo Prompt is a central part of the whole session, not just an occasional side tool

Practical tradeoff summary:
- `rp-cli` is ephemeral per invocation
- direct MCP is persistent per session
- `rp-cli` is great for shell composition
- direct MCP is better when you want stable bound context over time

Core rule that stays true in both lanes:
selection is context.
Whether you reached Repo Prompt through `rp-cli` or direct MCP, the selected files are what chat/review/agent flows actually see.

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
With `rp-cli`, remember that window/tab targeting is usually explicit per invocation unless you rely on Repo Prompt's active state or a wrapper like `rpflow`.

### 2) Build selection deliberately

Use:
- `manage_selection` for full files, codemap-only files, or slices
- `file_search`, `get_file_tree`, `get_code_structure`, and `read_file` for discovery
- `git` for diff/log/show/blame context

Why this matters:
- codemaps are tree-sitter-backed signatures, which lets Repo Prompt include far more reference files with far fewer tokens
- slices are the precision tool when full-file context would be wasteful
- multi-root workspaces let the same flow span monorepos, service fleets, or related repos cleanly

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
1. a discovery agent explores the repo, including codemaps and slices where useful, and curates the relevant files
2. an analysis model turns that curated context into a plan, review, answer, or investigation result

This separation is the whole trick: the implementation agent stays focused on acting, while Context Builder burns the exploration budget.

Prefer `context_builder` over hand-rolled builder command strings when you want Repo Prompt to discover relevant files.

```bash
rp-cli -c context_builder -j '{
  "instructions": "<task>Trace the login flow</task><context>Need the real auth path and edge cases.</context>",
  "response_type": "plan"
}'
```

Useful `response_type` values:
- `clarify` = curated context only
- `plan` = implementation plan grounded in repo reality
- `question` = answer a deep codebase question
- `review` = code review with git-context awareness

Deep review note:
- the review lane is valuable because it maps surrounding files/dependencies and catches issues that isolated diff reviews miss
- use it before commit when possible, while fixes are still cheap

Budget reality:
- the default builder budget is calibrated around ChatGPT Pro-style paste flows
- most models have an effective context window smaller than the advertised max
- codemaps + slices + manual refinement are how you stay in the useful zone instead of shoveling tokens blindly

### 3.5) Use git-aware review when the task is about changes

Repo Prompt's git/review surface is one of the highest-value reasons to use it instead of a dumb diff-only flow.

Use:
- `git` for `status`, `diff`, `log`, `show`, and `blame`
- `Review` / `/rp-review` when you want deep review grounded in the surrounding codebase, not just isolated line changes

Useful compare scopes include:
- uncommitted changes
- staged changes
- recent commits like `back:3`
- branch comparisons like `main...HEAD`

Important nuance:
- multi-root workspaces can review/query multiple repos
- git worktrees are supported, including `:worktree` / `:main` targeting
- Jujutsu (`jj`) repos are supported too; staged/unstaged concepts collapse into the jj-style working-copy reality

Examples:

```bash
rp-cli -c git -j '{"op":"status"}'
rp-cli -c git -j '{"op":"diff","compare":"staged","detail":"files"}'
rp-cli -c git -j '{"op":"log","count":5}'
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

Preset selection should match the lane:
- `Standard` / generic export when you want copy-paste into external chat
- `Plan` when you want architectural thinking before implementation
- `XML Edit` / `Pro Edit` when you want patch/apply/review flows
- `MCP Builder`, `MCP Pair`, `MCP Agent` when priming MCP-connected workflows

### 5) Use Oracle Chat and Agent Mode intentionally

Oracle Chat is useful when you want to ask Repo Prompt questions about the codebase mid-session without manually rebuilding context yourself.
Use:
- `oracle_send` for the actual question / plan / review turn
- `oracle_utils` for models and session helpers

That is especially useful when an agent needs a second opinion or a grounded repo answer while already working.
Oracle is strongest when treated as an ongoing reasoning conversation, not a one-shot lookup.
Repo Prompt keeps Oracle context synced with what the agent has already read, then lets Context Builder add even denser targeted context for the exact question.

Agent Mode now centers on:
- `agent_manage` for agent/model/workflow discovery and session management
- `agent_run` for start/poll/wait/steer/respond

Key Agent Mode characteristics worth actually using:
- native session host for CLI agents like Codex, Claude Code, and Gemini CLI
- per-tab sessions, so parallel work can stay isolated
- live streaming and Context Builder integration
- token-efficient MCP tools instead of wasteful built-in equivalents when available

Provider reality check:
- Codex CLI is the recommended lane: native app-server integration, strong agent control, compaction support, configurable tool preferences, and reasoning effort settings
- Claude Code is a solid full-featured lane with compaction and deep MCP integration
- Claude Code GLM is available via the Claude Code infrastructure when a Z.AI API key is configured
- Gemini CLI is still beta and currently lacks some capabilities like compaction and bash-tool parity

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
- `Plan & Build` = quick scan → Context Builder plan → Oracle refinement → implementation
- `Review` = survey git state → confirm scope → Context Builder review → fill gaps if needed
- `Refactor` = analyze with review-style context → plan improvements → implement while preserving behavior
- `Investigate` = assess → explore → deep-dive follow-ups → evidence gathering → findings report
- `ChatGPT Export` = Context Builder clarify-mode curation → prompt export for an external second opinion

The point of these workflows is that your task description gets wrapped in a proven protocol.
The agent does not have to reinvent the approach from scratch every time.

Repo Prompt also exposes workflow-oriented slash-command style affordances in some MCP clients, such as `/rp-build`, `/rp-review`, `/rp-refactor`, `/rp-investigate`, and `/rp-oracle-export`.
Treat those as first-class current product behavior, not trivia.
In Claude Code specifically, telling the user/agent to type `/repo` is the fast way to discover the installed Repo Prompt command set.

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
- first-time setup/testing for providers happens in the Repo Prompt app itself; the onboarding wizard and provider settings are the right place to verify connections

## CLI providers and when rpflow is still worth using

Repo Prompt can use CLI-provider-backed models too.
That means Agent Mode, Chat Mode, and Context Builder can ride existing Claude / ChatGPT / Google subscriptions in supported setups instead of requiring separate API billing for everything.
That is one of the strongest reasons to prefer the real Repo Prompt surfaces over homegrown wrappers when those surfaces are available.

Provider guidance in practice:
- CLI providers are the cost-leverage lane when you already pay for the subscriptions
- OpenRouter is great for experimentation, variety, and fallback access
- direct native providers are usually the better primary lane for your most important models
- custom providers/custom base URLs are the right answer for self-hosted or company OpenAI-compatible endpoints

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
And it should not try to become a bad clone of interactive Agent Mode features like per-tab sessions, Oracle questioning, image attachments, workflow-driven agent UX, or the IDE Mode Compose/Chat/Apply/Review and preset-driven workflow experience.

## Repo Prompt skills vs OpenClaw skills

Do not confuse these.

- This file is an OpenClaw skill about how to use Repo Prompt.
- Repo Prompt also has its own skills/slash-command system for agents.

Repo Prompt skills are markdown prompt templates discovered from on-disk directories and invoked as slash commands.
They are separate from OpenClaw skills.

Important locations:
- Claude Code: `<project>/.claude/skills/`, `<project>/.claude/commands/`, `~/.claude/skills/`, `~/.claude/commands/`
- Codex CLI / Gemini CLI: `<project>/.agents/skills/`, `<project>/.agents/slash/`, `~/.agents/skills/`, `~/.agents/slash/`

Repo Prompt can install built-in workflow skills for terminal agents too, so external agents can use the same workflow family from slash commands.
That includes built-in skills like `/rp-build`, `/rp-review`, `/rp-refactor`, `/rp-investigate`, and `/rp-oracle-export` when installed.
In Agent Mode itself, use either a workflow or a slash skill for a message, not both.

A practical special case: `claude-rp` is a Repo Prompt-provided Claude Code wrapper that boots Claude Code against Repo Prompt MCP directly and disables Claude's built-in file-operation tools, so Claude leans on Repo Prompt's codemaps/slices/selection machinery instead of wasting context on raw file ops.

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

## MCP server setup and security realities

Useful setup shorthand:
- enable the MCP server in Repo Prompt settings
- use the MCP popover/dashboard as the primary control point when possible
- prefer Repo Prompt's install/copy-config actions for clients like Cursor, VS Code, Codex CLI, Gemini CLI, Claude Desktop, or Claude Code
- install `rp-cli` from Repo Prompt settings when you need terminal access to MCP tools
- restart the client after first setup if it cached an empty tool list
- approve the connection in Repo Prompt when prompted

Architecture/security notes that matter operationally:
- Repo Prompt's MCP path is local-only with no exposed TCP ports in the normal UNIX-socket path
- socket/session state is per-user, so cross-user access is not the default model
- traffic is brokered through the Repo Prompt app and local IPC rather than exposing random open network services by default
- connection approval and per-tool enable/disable happen in Repo Prompt, not rpflow
- each CLI instance has its own session identity for connection management
- clients can automatically reconnect after Repo Prompt restarts or becomes temporarily unavailable
- only one Repo Prompt window owns the MCP server at a time
- `agent_run` / `agent_manage` are advanced control-plane tools and may be policy-gated on some connections
- the MCP dashboard can show active clients and disconnect stale ones when needed
- status UI matters: Server Off / Listening / Connecting / Connected / Tool Running are meaningful operational states

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
