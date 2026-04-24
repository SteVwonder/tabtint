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
assert_file "$PLUGIN/hooks.json"
assert_file "$PLUGIN/hooks/hooks.json"
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
assert_json "$PLUGIN/hooks.json"
assert_json "$PLUGIN/hooks/hooks.json"

jq -e '
  .name == "tabtint-iterm2"
  and .hooks == "./hooks.json"
  and .interface.displayName == "Tabtint for iTerm2"
' "$PLUGIN/.codex-plugin/plugin.json" >/dev/null || fail "plugin manifest metadata mismatch"

jq -e '
  .name == "tabtint-iterm2"
  and .hooks == "./hooks/hooks.json"
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

  (.hooks.SessionStart[0].matcher == "startup|resume")
  and (.hooks.UserPromptSubmit[0].matcher == "")
  and (.hooks.PreToolUse[0].matcher == "Bash")
  and (.hooks.PermissionRequest[0].matcher == "Bash")
  and (.hooks.PostToolUse[0].matcher == "Bash")
  and (.hooks.Stop[0].matcher == "")
  and ([hook_commands("SessionStart"),
        hook_commands("UserPromptSubmit"),
        hook_commands("PreToolUse"),
        hook_commands("PermissionRequest"),
        hook_commands("PostToolUse"),
        hook_commands("Stop")]
    | all(. == ["./scripts/tabtint-iterm2"]))
' "$PLUGIN/hooks.json" >/dev/null || fail "Codex hooks.json mismatch"

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

grep -q $'\033]1337;SetColors=tab=5fff87\a' "$tmp/running" || fail "running color mismatch"
grep -q $'\033]1337;SetColors=tab=ff5f87\a' "$tmp/approval" || fail "approval color mismatch"
grep -q $'\033]1337;SetColors=tab=5fd7ff\a' "$tmp/idle" || fail "idle color mismatch"
grep -q $'\033]1337;SetColors=tab=default\a' "$tmp/reset" || fail "reset color mismatch"

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
