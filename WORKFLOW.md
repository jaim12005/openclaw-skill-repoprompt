Repo Prompt default workflow (OpenClaw)

Goal: start repo work with Repo Prompt's MCP surface first, then use rpflow only when you specifically want shell-level determinism, retries, or exported artifacts.

Preflight (recommended, not mandatory for every tiny action):
1) Bind Repo Prompt to the repo by working directory when possible
2) Set RP_WORKSPACE / RP_TAB / RP_WINDOW only if you truly need pinned routing
3) Run bash scripts/preflight.sh before large shell-driven flows

Routing rule:
- Prefer `bind_context` with `working_dirs`
- Prefer the active Repo Prompt binding/workspace/tab over hardcoded `GitHub` / `T1`
- Use explicit workspace names only when you are intentionally targeting a specific workspace

Core flow:
1) Bind by repo path
2) Decide whether this is an IDE-manual task or an MCP/agent task
   - IDE/manual lane when you want hand-curated context, copy presets, built-in chat, or Apply/Review control
   - MCP/agent lane when you want automation, workflows, Oracle, or long-running agent sessions
3) For IDE/manual work, choose the right workflow shape
   - Copy & Paste for quick small tasks
   - Built-in Chat for iterative exploration
   - Architectural Planning for 3+ file or system-shaping tasks
   - XML Pro Edit for multi-file edits with review
   - Pair Programming for very large iterative work
4) For Agent/MCP work, choose the right workflow shape up front
   - `Plan & Build` for most implementation work
   - `Review` before committing or when auditing diffs
   - `Investigate` for debugging and root-cause work
   - `Refactor` for cleanup/restructure while preserving behavior
   - `ChatGPT Export` when you want an external second opinion
5) Let the workflow own the protocol when you use one
   - the workflow should handle discovery vs implementation sequencing
   - use Oracle follow-ups when the workflow benefits from architectural clarification
   - in external agents, `/repo` is often the fastest way to discover the available Repo Prompt workflow commands
6) Anchor selection (small, full content)
7) Use `context_builder` for discovery-heavy work
   - `clarify` for curated context only
   - `plan` for implementation planning
   - `question` for grounded answers
   - `review` for git-aware review output
8) Manually refine after discovery when the task is important
   - drop irrelevant files
   - promote key files to full content
   - keep reference files as codemaps
   - keep giant files sliced instead of full when possible
9) Add codemap_only or slices only where they help token discipline
10) Export prompt/context only if an artifact is useful
11) Choose execution lane:
   - IDE lane: Compose → Chat or Copy → Apply → Review
   - MCP direct lane: `apply_edits`, `file_actions`, `git`, `read_file`, `workspace_context`, `oracle_send`
   - Agent lane: `agent_manage` / `agent_run` with a workflow like `Plan & Build`, `Review`, `Refactor`, or `Investigate`
   - rpflow lane: wrapper-driven shell automation when retry/fallback/report-json/export behavior matters
12) For risky edits, require edit review before apply
13) Verify in Repo Prompt diff/review mode, iterate

Context hygiene reminders:
- use git diffs when recent changes are the point
- prefer effective-context discipline over max-context bragging rights
- for larger tasks, plan first and implement second instead of asking one model to improvise the whole thing in one pass

Recommended scripts:
- scripts/preflight.sh (fast validation)
- bash scripts/context-flow.sh (shell-friendly context flow)
- bash scripts/plan-export.sh (plan + export with retry/fallback)
- scripts/agent-safe.sh (plan-export + Agent safety prompt + Agent Mode kickoff via `agent_run`)
- scripts/export-prompt.sh (selection + export)

Examples:
- Full flow on the OpenClaw workspace root:
  bash scripts/context-flow.sh --workspace OpenClawWorkspace \
    --select-set "AGENTS.md,skills/repoprompt/" \
    --task "Review Repo Prompt automation wrappers" \
    --codemap "skills/repoprompt/scripts" \
    --slice "skills/repoprompt/WORKFLOW.md:1-120:workflow" \
    --out /tmp/rp-context.md

- Plan-only export on the repoprompt skill repo itself:
  bash scripts/plan-export.sh \
    --select-set "README.md,SKILL.md,scripts/" \
    --task "Update the skill for MCP-first Repo Prompt guidance" \
    --out /tmp/rp-plan.md

- Agent-safe kickoff (recommended for risky work):
  bash scripts/agent-safe.sh \
    --select-set "README.md,SKILL.md,WORKFLOW.md,scripts/" \
    --task "Propose and implement docs updates with safe review checkpoints" \
    --out /tmp/rp-agent-safe.md \
    --reasoning medium --mode plan --model-id engineer

Notes:
- If multiple Repo Prompt windows are open, set RP_WINDOW or pass -w to scripts.
- Use codemap_only for reference files to keep token budgets low.
- Use slices for tight, high-signal ranges instead of full files.
- For long agent sessions, keep periodic exports/checkpoints.
- Prefer `bind_context` and current active routing over stale hardcoded workspace assumptions.
- In Repo Prompt itself, workflows and slash skills are different tools; use one or the other per message, not both.
- Repo Prompt slash skills are not OpenClaw skills; they are Repo Prompt-local markdown templates discovered from `.claude/*` or `.agents/*` paths.
