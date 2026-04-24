#!/usr/bin/env bash
# Idempotently installs iTerm2 tab-state hook entries into Claude Code settings.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/tabtint-iterm2"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
BAK="$SETTINGS.bak"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

if [[ ! -f "$HOOK_SCRIPT" ]]; then
  echo "error: hook script not found at $HOOK_SCRIPT" >&2
  exit 1
fi

mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || printf '{}\n' > "$SETTINGS"

EVENTS=(
  SessionStart
  UserPromptSubmit
  PreToolUse
  PermissionRequest
  PostToolUse
  Notification
  Stop
  SessionEnd
)

cp -- "$SETTINGS" "$BAK"
echo "backup: $BAK"

tmp="$(mktemp)"
trap 'rm -f "$tmp" "$tmp.new"' EXIT

cp -- "$SETTINGS" "$tmp"

for evt in "${EVENTS[@]}"; do
  jq --arg evt "$evt" --arg cmd "$HOOK_SCRIPT" '
    .hooks //= {}
    | .hooks[$evt] //= []
    | .hooks[$evt] |= [
        .[]
        | .hooks = ([
            .hooks[]?
            | (.command // "") as $hook_cmd
            | select(
                $hook_cmd != $cmd
                and (($hook_cmd | endswith("/tabtint-iterm2")) | not)
              )
          ])
        | select((.hooks | length) > 0)
      ]
    | .hooks[$evt] += [{
      matcher: "",
      hooks: [{
        type: "command",
        command: $cmd,
        timeout: 2,
        async: true
      }]
    }]
  ' "$tmp" > "$tmp.new"
  mv -- "$tmp.new" "$tmp"
done

jq empty "$tmp"
mv -- "$tmp" "$SETTINGS"
trap - EXIT

echo "installed: Claude Code Tabtint iTerm2 hooks -> $HOOK_SCRIPT"
