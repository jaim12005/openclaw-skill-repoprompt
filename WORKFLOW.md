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
2) Choose the right workflow shape up front
   - `Plan & Build` for most implementation work
   - `Review` before committing or when auditing diffs
   - `Investigate` for debugging and root-cause work
   - `Refactor` for cleanup/restructure while preserving behavior
   - `ChatGPT Export` when you want an external second opinion
3) Let the workflow own the protocol when you use one
   - the workflow should handle discovery vs implementation sequencing
   - use Oracle follow-ups when the workflow benefits from architectural clarification
   - in external agents, `/repo` is often the fastest way to discover the available Repo Prompt workflow commands
4) Anchor selection (small, full content)
5) Use `context_builder` for discovery-heavy work
   - `clarify` for curated context only
   - `plan` for implementation planning
   - `question` for grounded answers
   - `review` for git-aware review output
6) Add codemap_only or slices only where they help token discipline
7) Export prompt/context only if an artifact is useful
8) Choose execution lane:
   - MCP direct lane: `apply_edits`, `file_actions`, `git`, `read_file`, `workspace_context`, `oracle_send`
   - Agent lane: `agent_manage` / `agent_run` with a workflow like `Plan & Build`, `Review`, `Refactor`, or `Investigate`
   - rpflow lane: wrapper-driven shell automation when retry/fallback/report-json/export behavior matters
9) For risky edits, require edit review before apply
10) Verify in Repo Prompt diff/review mode, iterate

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
