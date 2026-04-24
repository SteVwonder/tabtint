# Tabtint

Tabtint is a small plugin marketplace and hook installer for tinting terminal tabs from local coding-agent state.

The first package, `tabtint-iterm2`, provides lifecycle hooks for Codex and Claude Code that set the current iTerm2 tab color:

- Running: green, `5fff87`
- Permission prompt: red, `ff5f87`
- Idle or done: blue, `5fd7ff`

The hook writes iTerm2 OSC 1337 tab-color sequences directly to the controlling terminal, or to `AGENT_ITERM_TAB_TTY` when set. It does not print escape codes to stdout, so hook output remains clean.

## Install for Codex

Add the marketplace from GitHub:

```bash
codex plugin marketplace add sherbein/tabtint --ref main
```

Restart Codex, open the plugin browser, and install `tabtint-iterm2` from the `tabtint` marketplace:

```text
/plugins
```

Codex plugin installation caches and enables the package, but it does not write lifecycle hooks into your active config. Enable actual tab tinting by asking Codex to run the plugin's installer skill:

```text
Install Tabtint Codex hooks
```

That prompt uses the plugin's `install-codex-hooks` skill. The skill is configured as an explicit action rather than auto-loadable model context in both Codex and Claude Code. Codex will run the bundled installer from its plugin cache and may ask for permission before updating `~/.codex/config.toml` and `~/.codex/hooks.json`.

For local development before publishing:

```bash
codex plugin marketplace add /path/to/tabtint
```

## Install for Claude Code

Add the marketplace from GitHub:

```bash
claude plugin marketplace add sherbein/tabtint
claude plugin install tabtint-iterm2@tabtint
```

Or use the interactive commands inside Claude Code:

```text
/plugin marketplace add sherbein/tabtint
/plugin install tabtint-iterm2@tabtint
```

For local development before publishing:

```bash
claude plugin marketplace add /path/to/tabtint
claude plugin install tabtint-iterm2@tabtint
```

## Standalone Install

The plugin installers are useful in sandboxes or environments where plugin installation is unavailable.

Install into Codex:

```bash
bash plugins/tabtint-iterm2/scripts/install-codex-standalone.sh
```

Install into Claude Code:

```bash
bash plugins/tabtint-iterm2/scripts/install-claude-standalone.sh
```

Target a non-default config location:

```bash
CODEX_HOME=/path/to/codex-home bash plugins/tabtint-iterm2/scripts/install-codex-standalone.sh
CLAUDE_SETTINGS=/path/to/settings.json bash plugins/tabtint-iterm2/scripts/install-claude-standalone.sh
```

Both installers create `.bak` backups before changing config.

## Compatibility

`tabtint-iterm2` is intentionally iTerm2-specific. It uses `OSC 1337;SetColors=tab=...`, which is documented by iTerm2 and is not a general terminal standard.

Ghostty does not support iTerm2 tab tinting. A future Tabtint plugin could target Ghostty with its supported `OSC 9;4` progress indicator instead.

## Repository Layout

This repository is both a Codex marketplace and a Claude Code marketplace:

```text
tabtint/
  .agents/plugins/marketplace.json
  .claude-plugin/marketplace.json
  plugins/
    tabtint-iterm2/
      .codex-plugin/plugin.json
      .claude-plugin/plugin.json
      hooks/hooks.json
      skills/install-codex-hooks/
        SKILL.md
        agents/openai.yaml
      scripts/tabtint-iterm2
      scripts/install-codex-standalone.sh
      scripts/install-claude-standalone.sh
  tests/test-package.sh
```

The two agents use separate marketplace and plugin metadata, but they call the same bundled script. Codex does not currently install hook definitions directly from plugin manifests, so the Codex plugin includes an installer skill that writes supported entries into `~/.codex/hooks.json`.

## Configuration

Disable Tabtint:

```bash
export AGENT_ITERM_TAB_STATE=0
```

Override the terminal target:

```bash
export AGENT_ITERM_TAB_TTY=/dev/ttys001
```

Override colors:

```bash
export AGENT_ITERM_TAB_RUNNING=5fff87
export AGENT_ITERM_TAB_APPROVAL=ff5f87
export AGENT_ITERM_TAB_IDLE=5fd7ff
export AGENT_ITERM_TAB_ERROR=ff5f87
```

Agent-specific variables are also supported: `CODEX_ITERM_TAB_*` and `CLAUDE_ITERM_TAB_*`.

## Test

Run the package test:

```bash
bash tests/test-package.sh
```

Validate the Claude marketplace and plugin metadata:

```bash
claude plugin validate .
claude plugin validate plugins/tabtint-iterm2
```

Validate JSON and shell syntax:

```bash
jq empty .agents/plugins/marketplace.json .claude-plugin/marketplace.json plugins/tabtint-iterm2/.codex-plugin/plugin.json plugins/tabtint-iterm2/.claude-plugin/plugin.json plugins/tabtint-iterm2/hooks/hooks.json
bash -n plugins/tabtint-iterm2/scripts/tabtint-iterm2 plugins/tabtint-iterm2/scripts/install-codex-standalone.sh plugins/tabtint-iterm2/scripts/install-claude-standalone.sh tests/test-package.sh
```
