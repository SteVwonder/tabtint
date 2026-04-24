---
name: install-codex-hooks
description: Use when a user wants to enable or verify Tabtint iTerm2 lifecycle hooks for Codex after installing the tabtint-iterm2 plugin.
disable-model-invocation: true
---

# Install Codex Hooks

## Goal

Install Tabtint into the user's active Codex configuration without asking the user to manually run the installer script.

## Steps

1. Resolve the plugin root from this skill file path. This skill lives at `skills/install-codex-hooks/SKILL.md`, so the plugin root is the directory that contains `skills/`.
2. Run `bash <plugin-root>/scripts/install-codex-standalone.sh`. If the command needs permission to write outside the current workspace, request approval and explain that it updates the user's Codex config.
3. Verify that `<CODEX_HOME:-$HOME/.codex>/hooks.json` contains Tabtint command hooks pointing at `<plugin-root>/scripts/tabtint-iterm2`.
4. Verify that `<CODEX_HOME:-$HOME/.codex>/config.toml` contains `codex_hooks = true`.
5. Tell the user to start a new Codex session if the current session does not pick up the changed hook config.

## Notes

Do not patch Codex source code for this setup. Current Codex plugin manifests can provide skills, MCP servers, apps, and interface metadata; they do not directly install hook definitions. The installer writes the supported `hooks.json` config that Codex already loads.
