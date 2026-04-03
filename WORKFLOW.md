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
2) Anchor selection (small, full content)
3) Use `context_builder` for discovery-heavy work
4) Add codemap_only or slices only where they help token discipline
5) Export prompt/context only if an artifact is useful
6) Choose execution lane:
   - MCP direct lane: `apply_edits`, `file_actions`, `git`, `read_file`, `workspace_context`, `oracle_send`
   - Agent lane: `agent_manage` / `agent_run` with a workflow like `Plan & Build`, `Review`, `Refactor`, or `Investigate`
   - rpflow lane: wrapper-driven shell automation when retry/fallback/report-json/export behavior matters
7) For risky edits, require edit review before apply
8) Verify in Repo Prompt diff/review mode, iterate

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
