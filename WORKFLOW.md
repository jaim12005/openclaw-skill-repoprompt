Repo Prompt default workflow (OpenClaw)

Goal: start repo work with deterministic context curation in Repo Prompt (selection + codemaps/slices + export), then run either deterministic edits or interactive Agent Mode (2.0) with clear approval policy.

Preflight (required):
1) Set deterministic defaults (env vars):
   - RP_WORKSPACE (for example GitHub, OpenClawWorkspace, RepoPromptSkill, RPFlowCLI)
   - RP_TAB (for example T1/T3)
   - RP_WINDOW (optional, required if multiple windows are open)
2) Run bash scripts/preflight.sh to verify Repo Prompt + MCP + tab/window.

Workspace choice rule:
- Use GitHub for repos rooted under ~/Documents/github
- Use a dedicated Repo Prompt workspace for repos outside that root
- Skill repos under ~/.openclaw/workspace/skills are a common case where a dedicated workspace is cleaner than assuming GitHub

Core flow:
1) Anchor selection (small, full content)
2) Context Builder for discovery
3) Add codemap_only for reference paths
4) Add slices for targeted ranges
5) Export prompt to a file (repeatable context)
6) Choose execution lane:
   - Deterministic lane: apply edits via apply_edits / file_actions only
   - Interactive lane: use Repo Prompt Agent (Codex preferred), set reasoning/tool/approval policy, iterate
7) For risky edits, require edit review before apply
8) Verify in Repo Prompt diff/review mode, iterate

Recommended scripts:
- scripts/preflight.sh (fast validation)
- bash scripts/context-flow.sh (full flow: anchor + builder + codemap + slices + export)
- bash scripts/plan-export.sh (plan + export)
- scripts/agent-safe.sh (plan-export + Agent safety prompt + optional chat kickoff)
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
  bash scripts/plan-export.sh --workspace RepoPromptSkill \
    --select-set "README.md,SKILL.md,scripts/" \
    --task "Add hybrid rpflow + Agent Mode guidance" \
    --out /tmp/rp-plan.md

- Agent-safe kickoff (recommended for risky work):
  bash scripts/agent-safe.sh --workspace RepoPromptSkill --tab T1 \
    --select-set "README.md,SKILL.md,WORKFLOW.md,scripts/" \
    --task "Propose and implement docs updates with safe review checkpoints" \
    --out /tmp/rp-agent-safe.md \
    --reasoning medium --mode plan

Notes:
- If multiple Repo Prompt windows are open, set RP_WINDOW or pass -w to scripts.
- Use codemap_only for reference files to keep token budgets low.
- Use slices for tight, high-signal ranges instead of full files.
- For long agent sessions, keep periodic exports/checkpoints.
