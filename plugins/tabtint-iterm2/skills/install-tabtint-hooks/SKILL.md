---
name: install-tabtint-hooks
description: Use when a user wants to enable or verify Tabtint iTerm2 lifecycle hooks after installing the tabtint-iterm2 plugin.
disable-model-invocation: true
---

# Install Tabtint Hooks

## Goal

Install Tabtint into the user's active agent configuration without asking the user to manually run the installer script.

## Steps

1. Resolve the plugin root from this skill file path. This skill lives at `skills/install-tabtint-hooks/SKILL.md`, so the plugin root is the directory that contains `skills/`.
2. Choose the target agent. If the user explicitly names Codex or Claude Code, use that target. Otherwise, use the currently running agent environment. If the target is unclear, ask which config to update before running an installer.
3. For Codex, run `bash <plugin-root>/scripts/install-codex-standalone.sh`. If the command needs permission to write outside the current workspace, request approval and explain that it updates the user's Codex config.
4. For Claude Code, run `bash <plugin-root>/scripts/install-claude-standalone.sh`. If the command needs permission to write outside the current workspace, request approval and explain that it updates the user's Claude Code settings.
5. For Codex, verify that `<CODEX_HOME:-$HOME/.codex>/hooks.json` contains Tabtint command hooks pointing at `<plugin-root>/scripts/tabtint-iterm2`, and verify that `<CODEX_HOME:-$HOME/.codex>/config.toml` contains `codex_hooks = true`.
6. For Claude Code, verify that `<CLAUDE_SETTINGS:-$HOME/.claude/settings.json>` contains Tabtint command hooks pointing at `<plugin-root>/scripts/tabtint-iterm2`.
7. Tell the user to start a new agent session if the current session does not pick up the changed hook config.
