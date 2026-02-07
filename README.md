# OpenClaw Skill: repoprompt

## Overview
Automate Repo Prompt (MCP + rp-cli) for context building, file selection, chat_send, edits, and exports.

This skill now treats rpflow as the preferred orchestration layer and raw rp-cli as the low-level fallback/debug interface.
Most wrappers in scripts/ now delegate to rpflow (bootstrap-github.sh is the one setup-time exception).

## Requirements
- Repo Prompt app running
- MCP Server enabled in Repo Prompt settings
- rp-cli on PATH
- rpflow repo available at $HOME/Documents/github/repoprompt-rpflow-cli (for preferred flows)

## Install (OpenClaw)
1) Clone this repo into ~/clawd/skills/repoprompt (or ~/.openclaw/skills/repoprompt).
2) Enable MCP Server in Repo Prompt and install rp-cli to PATH.
3) Restart the OpenClaw gateway.

## Usage
See SKILL.md for the operating model, command matrix, strict mode, timeout/fallback policy, and wrappers.

Quick wrapper example:
- `skills/repoprompt/scripts/rpflow.sh smoke`
- `skills/repoprompt/scripts/rpflow.sh exec -e 'tabs'`
- `skills/repoprompt/scripts/rpflow.sh autopilot --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --fallback-export-on-timeout`
- `skills/repoprompt/scripts/rpflow.sh autopilot --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --report-json /tmp/rpflow-run.json`
- `skills/repoprompt/scripts/rpflow.sh autopilot --profile fast --select-set repo/src/ --task "draft plan" --out /tmp/plan.md --retry-on-timeout --fallback-export-on-timeout`

## Sources
See SOURCES.md.
