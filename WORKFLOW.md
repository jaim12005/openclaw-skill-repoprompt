Repo Prompt default workflow (Clawdbot)

Goal: start repo work with deterministic context curation in Repo Prompt (selection + codemaps/slices + export), then run either deterministic edits or interactive Agent Mode (2.0) with clear approval policy.

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
6) Choose execution lane:
   - Deterministic lane: apply edits via apply_edits / file_actions only
   - Interactive lane: use Repo Prompt Agent (Codex preferred), set reasoning/tool/approval policy, iterate
7) For risky edits, require edit review before apply
8) Verify in Repo Prompt diff/review mode, iterate

Recommended scripts:
- scripts/preflight.sh (fast validation)
- bash scripts/context-flow.sh (full flow: anchor + builder + codemap + slices + export)
- bash scripts/plan-export.sh (plan + export)
- scripts/export-prompt.sh (selection + export)

Examples:
- Full flow (recommended):
  bash scripts/context-flow.sh --workspace Clawdbot     --select-set "skills/repoprompt/,AGENTS.md"     --task "Review Repo Prompt automation wrappers"     --codemap "skills/repoprompt/scripts"     --slice "skills/repoprompt/WORKFLOW.md:1-80:workflow"     --out /tmp/rp-context.md

- Plan-only export:
  bash scripts/plan-export.sh --workspace Clawdbot     --select-set "skills/repoprompt/"     --task "Add hybrid rpflow + Agent Mode guidance"     --out /tmp/rp-plan.md

Notes:
- If multiple Repo Prompt windows are open, set RP_WINDOW or pass -w to scripts.
- Use codemap_only for reference files to keep token budgets low.
- Use slices for tight, high-signal ranges instead of full files.
- For long agent sessions, keep periodic exports/checkpoints.