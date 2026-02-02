Repo Prompt default workflow (Clawdbot)

Goal: always start repo work by curating context in Repo Prompt (selection + codemaps/slices), then hand off a clean prompt/context file to an implementation agent.

Preflight (required):
1) Set deterministic defaults (env vars):
   - RP_WORKSPACE (e.g. Clawdbot or GitHub)
   - RP_TAB (e.g. T1/T3)
   - RP_WINDOW (optional, required if multiple windows are open)
2) Run bash scripts/preflight.sh to verify Repo Prompt + MCP + tab/window.

Core flow:
1) Anchor selection (small, full content)
2) Context Builder for discovery
3) Add codemap_only for reference paths
4) Add slices for targeted ranges
5) Export prompt to a file (repeatable context)
6) Implement with an agent using the exported prompt
7) Apply edits via apply_edits / file_actions only
8) Verify in Repo Prompt diff/review mode, iterate

Recommended scripts:
- scripts/preflight.sh (fast validation)
- bash scripts/context-flow.sh (full flow: anchor + builder + codemap + slices + export)
- bash scripts/plan-export.sh (plan + export)
- scripts/export-prompt.sh (selection + export)

Examples:
- Full flow (recommended):
  bash scripts/context-flow.sh --workspace Clawdbot     --select-set "skills/repoprompt/,AGENTS.md"     --task "Review Repo Prompt automation wrappers"     --codemap "skills/repoprompt/scripts"     --slice "skills/repoprompt/WORKFLOW.md:1-60:workflow"     --out /tmp/rp-context.md

- Plan-only export:
  bash scripts/plan-export.sh --workspace Clawdbot     --select-set "skills/repoprompt/"     --task "Add preflight wrapper and context-flow helper"     --out /tmp/rp-plan.md

Notes:
- If multiple Repo Prompt windows are open, set RP_WINDOW or pass -w to scripts.
- Use codemap_only for reference files to keep token budgets low.
- Use slices for tight, high-signal ranges instead of full files.
