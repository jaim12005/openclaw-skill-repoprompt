---
name: repoprompt
description: Automate Repo Prompt (MCP + rp-cli) for context building, file selection, chat_send, and exports. Provides patterns for window/tab targeting and scripting.
metadata: {"clawdbot": {"permissions": ["filesystem:$HOME/Documents/github", "mcp"]}}
---

# Repo Prompt Automation (rp-cli + MCP)

Use this skill when you need to drive the Repo Prompt macOS app programmatically (for context building, prompt export, chat, file edits, git reviews).

## Prereqs / Assumptions

- Repo Prompt app is running.
- In Repo Prompt: Settings → MCP Server → MCP Server enabled.
- rp-cli is installed to PATH (Repo Prompt can install it via Settings → MCP Server → Install CLI to PATH).
- MCP connections require user approval and tool access control in Repo Prompt.

## Local defaults (this machine)

- Default repo base folder: $HOME/Documents/github
- Default Repo Prompt workspace name: GitHub
- Default compose tab (for automation): T1
- Window selection: single window by default; set RP_WINDOW (or pass -w) if multiple windows

You can override defaults per-command by passing flags, or globally by setting environment variables:
- RP_WORKSPACE (default: GitHub)
- RP_TAB (default: T1)
- RP_WINDOW (optional, required if multiple windows are open)

## Key Concepts (from Repo Prompt docs)

- **Selection is context**: Repo Prompt chat (and many workflows) only see what is currently selected.
- **Selection modes**: full, slices (line ranges), and codemap_only (signatures only) for token-efficient context.
- **MCP server**: lets agents select files, read code structure, and apply edits through standardized tools.
- **Context Builder**: uses tree-sitter and parallel parsing to auto-select relevant files.
- **Multi-root workspaces**: analyze multiple repos as a unified context.
- **CLI Providers**: use existing subscriptions (Claude, ChatGPT, Google AI) without extra API cost.

## MCP Tool Categories (Docs Summary)

- **Selection & Context**: manage_selection, workspace_context, prompt, context_builder
- **File Operations**: get_file_tree, file_search, read_file, get_code_structure, file_actions, apply_edits
- **Chat & Models**: chat_send, chats, list_models
- **Workspaces**: manage_workspaces

## Recommended operating pattern ("Repo Prompt first")

When a request is about a codebase (debugging, feature work, refactor, PR review), do this before answering or editing:
- Switch to the correct workspace
- Build a tight selection (folder(s) and/or a small set of files)
- Use builder for discovery/plan/review when appropriate
- Export the resulting prompt/context to a file (so it’s repeatable)
- If edits are needed, prefer JSON calls (apply_edits / file_actions) so changes are structured and reviewable

## Common Recipes (Exec mode)

```bash
# Discover windows/tabs
rp-cli -e 'windows'
rp-cli -w 1 -e 'tabs'

# Build selection + export LLM-ready prompt
rp-cli -w 1 -t MyTab -e 'workspace switch MyProject && select set src/ && prompt export ~/context.md'

# Context builder (context only)
rp-cli -w 1 -t MyTab -e 'builder "find auth code"'

# Context builder + plan
rp-cli -w 1 -t MyTab -e 'builder "add logout" --type plan'

# Chat / continue chat
rp-cli -w 1 -t MyTab -e 'chat "Explain this code" --new'
```

## JSON-first calls (for editing)

apply_edits and file_actions are easiest via JSON:

```bash
rp-cli -w 1 -t MyTab -e 'call apply_edits {"path":"src/a.ts","search":"old","replace":"new","all":true}'
rp-cli -w 1 -t MyTab -e 'call file_actions {"action":"create","path":"src/new.ts","content":"export {}
"}'
```

## Best Practices

- Use codemap_only for reference files, full for files being edited, slices for targeted context.
- Prefer context_builder for large repos or ambiguous asks; refine selection manually if needed.
- Keep selections small and reviewable; export prompt snapshots when handing off to coding agents.
- For multi-repo work, use a multi-root workspace rather than stitching separate prompts.

## Troubleshooting

- If rp-cli can’t see files, confirm you’re in the correct workspace and that the workspace root contains the target path.
- If multiple Repo Prompt windows are open, pass -w on every rp-cli call.
- If MCP tools are missing, re-enable MCP Server and re-approve the connection in Repo Prompt.
- Cursor one-click setup is available; other editors require manual MCP configuration.

## Scripts

See ./scripts/ for helper wrappers (optional). They are intentionally lightweight and safe.

Key ones on this machine:
- scripts/preflight.sh: validates Repo Prompt + MCP + window/tab before automation.
- scripts/context-flow.sh: end-to-end flow (anchor selection + Context Builder + codemap_only + slices + export).
- scripts/bootstrap-github.sh: creates $HOME/Documents/github (if needed) and ensures a Repo Prompt workspace named GitHub points at it.
- scripts/export-prompt.sh: selection → prompt export (good for handing off context).
- scripts/plan-export.sh: selection → Context Builder (plan) → prompt export.

## Coding-agent handoff (recommended)

When you want an implementation agent (Codex/Claude Code/etc.) to do the actual edits:
1) Use plan-export.sh to generate a single context file.
2) Run the coding agent in the repo’s folder, and tell it to read that context file as the source of truth.
3) Apply multi-file edits back through Repo Prompt (apply_edits/file_actions) where possible.
