#!/bin/bash
# Install or uninstall iterative-improve gate hooks in the current project.

set -euo pipefail

repo_raw_url="${ITERATIVE_IMPROVE_RAW_URL:-https://raw.githubusercontent.com/Heller2333/iterative-improve/main}"
project_root="$(pwd)"
claude_dir="$project_root/.claude"
hooks_dir="$claude_dir/hooks"
settings_file="$claude_dir/settings.json"
hook_file="$hooks_dir/iterative-improve-gate.sh"
hook_command=' "$CLAUDE_PROJECT_DIR"/.claude/hooks/iterative-improve-gate.sh'
hook_command="${hook_command# }"
mode="install"

usage() {
  cat <<'EOF'
Usage:
  bash install.sh
  bash install.sh --uninstall

Run from the target project root. This script only modifies the current
project's .claude/ files and .gitignore.
EOF
}

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

timestamp() {
  date -u +"%Y%m%dT%H%M%SZ"
}

backup_settings() {
  [ -f "$settings_file" ] || return 0
  cp "$settings_file" "$settings_file.bak.$(timestamp)"
}

require_jq() {
  command -v jq >/dev/null 2>&1 || fail "jq is required to merge .claude/settings.json safely. Install jq, then rerun this script."
}

validate_settings() {
  [ -f "$settings_file" ] || return 0
  jq empty "$settings_file" >/dev/null 2>&1 || fail "$settings_file is not valid JSON. A backup was created; fix the JSON and rerun install.sh."
}

write_default_settings_if_missing() {
  if [ ! -f "$settings_file" ]; then
    mkdir -p "$claude_dir"
    printf '{}\n' > "$settings_file"
  fi
}

install_hook_file() {
  local source_hook
  source_hook="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/scripts/claude-code-gate.sh"

  mkdir -p "$hooks_dir"

  if [ -f "$source_hook" ]; then
    cp "$source_hook" "$hook_file"
  else
    command -v curl >/dev/null 2>&1 || fail "curl is required when install.sh is not run from a cloned repository."
    curl -fsSL "$repo_raw_url/scripts/claude-code-gate.sh" -o "$hook_file.tmp"
    mv "$hook_file.tmp" "$hook_file"
  fi

  chmod +x "$hook_file"
}

merge_settings() {
  local tmp
  tmp="$(mktemp)"

  jq --arg cmd "$hook_command" '
    .hooks = (.hooks // {}) |
    .hooks.UserPromptSubmit = (
      (.hooks.UserPromptSubmit // []) as $arr |
      if any($arr[]?; any(.hooks[]?; .command == $cmd)) then
        $arr
      else
        $arr + [{"hooks": [{"type": "command", "command": $cmd}]}]
      end
    ) |
    .hooks.PreToolUse = (
      (.hooks.PreToolUse // []) as $arr |
      if any($arr[]?; any(.hooks[]?; .command == $cmd)) then
        $arr
      else
        $arr + [{"matcher": "Bash|Edit|Write|ExitPlanMode", "hooks": [{"type": "command", "command": $cmd}]}]
      end
    )
  ' "$settings_file" > "$tmp"

  mv "$tmp" "$settings_file"
}

unmerge_settings() {
  [ -f "$settings_file" ] || return 0

  local tmp
  tmp="$(mktemp)"

  jq --arg cmd "$hook_command" '
    .hooks = (.hooks // {}) |
    .hooks.UserPromptSubmit = [
      (.hooks.UserPromptSubmit // [])[]
      | .hooks = [(.hooks // [])[] | select(.command != $cmd)]
      | select((.hooks | length) > 0)
    ] |
    .hooks.PreToolUse = [
      (.hooks.PreToolUse // [])[]
      | .hooks = [(.hooks // [])[] | select(.command != $cmd)]
      | select((.hooks | length) > 0)
    ]
  ' "$settings_file" > "$tmp"

  mv "$tmp" "$settings_file"
}

append_gitignore() {
  local gitignore="$project_root/.gitignore"

  if [ -f "$gitignore" ] && grep -Eq '(^|/)\.scratch/|^\.scratch/agent-state/?$' "$gitignore"; then
    return 0
  fi

  {
    [ -s "$gitignore" ] && printf '\n'
    printf '# iterative-improve local gate state\n'
    printf '.scratch/agent-state/\n'
  } >> "$gitignore"
}

install_gate() {
  require_jq
  mkdir -p "$claude_dir"
  backup_settings
  validate_settings
  write_default_settings_if_missing
  install_hook_file
  merge_settings
  append_gitignore

  echo "iterative-improve gate installed in $project_root"
  echo "Restart Claude Code or reload project settings before using /iterative-improve."
}

uninstall_gate() {
  require_jq
  mkdir -p "$claude_dir"
  backup_settings
  validate_settings
  unmerge_settings
  rm -f "$hook_file"

  echo "iterative-improve gate uninstalled from $project_root"
  echo "The .gitignore entry and .scratch/agent-state/ are left in place intentionally."
}

case "${1:-}" in
  "")
    mode="install"
    ;;
  --uninstall)
    mode="uninstall"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [ "$mode" = "install" ]; then
  install_gate
else
  uninstall_gate
fi
