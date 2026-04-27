#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/tabtint-iterm2"

fail() {
  printf 'not ok: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "missing file: ${1#$ROOT/}"
}

assert_executable() {
  [[ -x "$1" ]] || fail "not executable: ${1#$ROOT/}"
}

assert_json() {
  jq empty "$1" >/dev/null || fail "invalid JSON: ${1#$ROOT/}"
}

[[ "$(basename "$ROOT")" == "tabtint" ]] || fail "repository directory must be named tabtint"
assert_file "$ROOT/README.md"
assert_file "$ROOT/.agents/plugins/marketplace.json"
assert_file "$ROOT/.claude-plugin/marketplace.json"
assert_file "$PLUGIN/.codex-plugin/plugin.json"
assert_file "$PLUGIN/.claude-plugin/plugin.json"
assert_file "$PLUGIN/hooks/hooks.json"
assert_file "$PLUGIN/skills/install-tabtint-hooks/SKILL.md"
assert_file "$PLUGIN/skills/install-tabtint-hooks/agents/openai.yaml"
assert_file "$PLUGIN/scripts/tabtint-iterm2"
assert_file "$PLUGIN/scripts/install-codex-standalone.sh"
assert_file "$PLUGIN/scripts/install-claude-standalone.sh"
assert_executable "$PLUGIN/scripts/tabtint-iterm2"
assert_executable "$PLUGIN/scripts/install-codex-standalone.sh"
assert_executable "$PLUGIN/scripts/install-claude-standalone.sh"

assert_json "$ROOT/.agents/plugins/marketplace.json"
assert_json "$ROOT/.claude-plugin/marketplace.json"
assert_json "$PLUGIN/.codex-plugin/plugin.json"
assert_json "$PLUGIN/.claude-plugin/plugin.json"
assert_json "$PLUGIN/hooks/hooks.json"

jq -e '
  .name == "tabtint-iterm2"
  and (.hooks | not)
  and .skills == "./skills"
  and .interface.displayName == "Tabtint for iTerm2"
  and .interface.defaultPrompt == ["$tabtint-iterm2:install-tabtint-hooks"]
' "$PLUGIN/.codex-plugin/plugin.json" >/dev/null || fail "plugin manifest metadata mismatch"

grep -q 'install-tabtint-hooks' "$PLUGIN/skills/install-tabtint-hooks/SKILL.md" || fail "Tabtint install skill missing expected name"
grep -q 'disable-model-invocation: true' "$PLUGIN/skills/install-tabtint-hooks/SKILL.md" || fail "Tabtint install skill must be explicit-only in Claude Code"
grep -q 'install-codex-standalone.sh' "$PLUGIN/skills/install-tabtint-hooks/SKILL.md" || fail "Tabtint install skill missing Codex installer reference"
grep -q 'install-claude-standalone.sh' "$PLUGIN/skills/install-tabtint-hooks/SKILL.md" || fail "Tabtint install skill missing Claude installer reference"
grep -q 'allow_implicit_invocation: false' "$PLUGIN/skills/install-tabtint-hooks/agents/openai.yaml" || fail "Tabtint install skill must not be auto-loadable"
grep -q 'default_prompt: "$tabtint-iterm2:install-tabtint-hooks"' "$PLUGIN/skills/install-tabtint-hooks/agents/openai.yaml" || fail "Tabtint install skill missing explicit default prompt metadata"
[[ ! -e "$PLUGIN/skills/install-codex-hooks" ]] || fail "old install skill directory remains"
! rg -n "install-codex-hooks" "$ROOT/README.md" "$PLUGIN/.codex-plugin/plugin.json" "$PLUGIN/skills/install-tabtint-hooks" >/dev/null || fail "old install skill name remains"
grep -q '^/install-tabtint-hooks$' "$ROOT/README.md" || fail "README missing Claude install slash command"
[[ ! -e "$PLUGIN/commands" ]] || fail "Codex does not support plugin commands; use skills instead"

jq -e '
  .name == "tabtint-iterm2"
  and (has("hooks") | not)
  and .description == "Tint iTerm2 tabs from local agent lifecycle state."
' "$PLUGIN/.claude-plugin/plugin.json" >/dev/null || fail "Claude plugin manifest metadata mismatch"

jq -e '
  .plugins
  | map(select(.name == "tabtint-iterm2"
    and .source.source == "local"
    and .source.path == "./plugins/tabtint-iterm2"
    and .policy.installation == "AVAILABLE"
    and .policy.authentication == "ON_INSTALL"))
  | length == 1
' "$ROOT/.agents/plugins/marketplace.json" >/dev/null || fail "marketplace entry mismatch"

jq -e '
  .name == "tabtint"
  and .owner.name == "sherbein"
  and (.plugins
    | map(select(.name == "tabtint-iterm2"
      and .source == "./plugins/tabtint-iterm2"
      and .description == "Tint iTerm2 tabs from local agent lifecycle state."))
    | length == 1)
' "$ROOT/.claude-plugin/marketplace.json" >/dev/null || fail "Claude marketplace entry mismatch"

jq -e '
  def hook_commands(event):
    [.hooks[event][]?.hooks[]? | select(.type == "command") | .command];

  ([hook_commands("SessionStart"),
    hook_commands("UserPromptSubmit"),
    hook_commands("PreToolUse"),
    hook_commands("PermissionRequest"),
    hook_commands("PostToolUse"),
    hook_commands("Notification"),
    hook_commands("Stop"),
    hook_commands("SessionEnd")]
    | all(. == ["${CLAUDE_PLUGIN_ROOT}/scripts/tabtint-iterm2"]))
' "$PLUGIN/hooks/hooks.json" >/dev/null || fail "Claude hooks/hooks.json mismatch"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run_hook() {
  local payload="$1"
  local output="$2"
  printf '%s' "$payload" | AGENT_ITERM_TAB_TTY="$output" "$PLUGIN/scripts/tabtint-iterm2"
}

run_hook '{"hook_event_name":"UserPromptSubmit"}' "$tmp/running"
run_hook '{"hook_event_name":"PermissionRequest"}' "$tmp/approval"
run_hook '{"hook_event_name":"Stop"}' "$tmp/idle"
AGENT_ITERM_TAB_TTY="$tmp/reset" "$PLUGIN/scripts/tabtint-iterm2" reset
AGENT_ITERM_TAB_STATE=0 AGENT_ITERM_TAB_TTY="$tmp/reset-disabled" "$PLUGIN/scripts/tabtint-iterm2" reset

grep -q $'\033]1337;SetColors=tab=5fd7ff\a' "$tmp/running" || fail "running color mismatch"
grep -q $'\033]1337;SetColors=tab=ff5f87\a' "$tmp/approval" || fail "approval color mismatch"
grep -q $'\033]1337;SetColors=tab=5fff87\a' "$tmp/idle" || fail "idle color mismatch"
grep -q $'\033]1337;SetColors=tab=default\a' "$tmp/reset" || fail "reset color mismatch"
grep -q $'\033]1337;SetColors=tab=default\a' "$tmp/reset-disabled" || fail "reset color mismatch when tabtint is disabled"

CODEX_HOME="$tmp/codex" "$PLUGIN/scripts/install-codex-standalone.sh" >/dev/null
jq -e --arg cmd "$PLUGIN/scripts/tabtint-iterm2" '
  [.hooks[]?[]?.hooks[]? | select(.command == $cmd)]
  | length == 6
' "$tmp/codex/hooks.json" >/dev/null || fail "Codex standalone installer did not write expected hooks"
grep -q 'codex_hooks = true' "$tmp/codex/config.toml" || fail "Codex standalone installer did not enable hooks"

CLAUDE_SETTINGS="$tmp/claude/settings.json" "$PLUGIN/scripts/install-claude-standalone.sh" >/dev/null
jq -e --arg cmd "$PLUGIN/scripts/tabtint-iterm2" '
  [.hooks[]?[]?.hooks[]? | select(.command == $cmd and .async == true)]
  | length == 8
' "$tmp/claude/settings.json" >/dev/null || fail "Claude standalone installer did not write expected hooks"

! rg -n "agent-iterm-tab-state|iTerm Tab State" "$ROOT" -g '!test-package.sh' >/dev/null || fail "old package names remain"

printf 'ok\n'
