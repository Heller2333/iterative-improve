#!/bin/bash
# Install, update, check, or uninstall iterative-improve gate hooks in the current project.

set -euo pipefail

repo_url="${ITERATIVE_IMPROVE_REPO_URL:-https://github.com/Heller2333/iterative-improve}"
repo_ref="${ITERATIVE_IMPROVE_REF:-main}"
repo_raw_url="${ITERATIVE_IMPROVE_RAW_URL:-https://raw.githubusercontent.com/Heller2333/iterative-improve/$repo_ref}"
project_root="$(pwd)"
claude_dir="$project_root/.claude"
hooks_dir="$claude_dir/hooks"
settings_file="$claude_dir/settings.json"
metadata_file="$claude_dir/iterative-improve.json"
hook_file="$hooks_dir/iterative-improve-gate.sh"
hook_command=' "$CLAUDE_PROJECT_DIR"/.claude/hooks/iterative-improve-gate.sh'
hook_command="${hook_command# }"
mode="install"
script_dir=""

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
fi

usage() {
  cat <<'EOF'
Usage:
  bash install.sh
  bash install.sh --update
  bash install.sh --check
  bash install.sh --version
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

require_curl() {
  command -v curl >/dev/null 2>&1 || fail "curl is required to fetch iterative-improve files from GitHub."
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
  source_hook="$script_dir/scripts/claude-code-gate.sh"

  mkdir -p "$hooks_dir"

  if [ -n "$script_dir" ] && [ -f "$source_hook" ]; then
    cp "$source_hook" "$hook_file"
  else
    require_curl
    curl -fsSL "$repo_raw_url/scripts/claude-code-gate.sh" -o "$hook_file.tmp"
    mv "$hook_file.tmp" "$hook_file"
  fi

  chmod +x "$hook_file"
}

local_version() {
  if [ -n "$script_dir" ] && [ -f "$script_dir/VERSION" ]; then
    sed -n '1p' "$script_dir/VERSION"
  else
    printf 'unknown\n'
  fi
}

latest_version() {
  require_curl
  curl -fsSL "$repo_raw_url/VERSION"
}

source_version() {
  local version
  version=$(local_version)
  if [ "$version" != "unknown" ]; then
    printf '%s\n' "$version"
  else
    latest_version
  fi
}

installed_version() {
  if [ -f "$metadata_file" ]; then
    jq -r '.version // "unknown"' "$metadata_file" 2>/dev/null || printf 'unknown\n'
  else
    printf 'not installed\n'
  fi
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

write_metadata() {
  local version="$1"
  local tmp
  tmp="$(mktemp)"

  jq -n \
    --arg repo "$repo_url" \
    --arg ref "$repo_ref" \
    --arg raw_url "$repo_raw_url" \
    --arg version "$version" \
    --arg installed_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg hook_path ".claude/hooks/iterative-improve-gate.sh" \
    --arg settings_path ".claude/settings.json" \
    '{
      repo: $repo,
      ref: $ref,
      raw_url: $raw_url,
      version: $version,
      installed_at: $installed_at,
      hook_path: $hook_path,
      settings_path: $settings_path
    }' > "$tmp"

  mv "$tmp" "$metadata_file"
}

install_gate() {
  local version
  require_jq
  mkdir -p "$claude_dir"
  backup_settings
  validate_settings
  write_default_settings_if_missing
  install_hook_file
  merge_settings
  append_gitignore
  version=$(source_version)
  write_metadata "$version"

  echo "iterative-improve gate installed in $project_root"
  echo "version: $version"
  echo "Restart Claude Code or reload project settings before using /iterative-improve."
}

uninstall_gate() {
  require_jq
  mkdir -p "$claude_dir"
  backup_settings
  validate_settings
  unmerge_settings
  rm -f "$hook_file"
  rm -f "$metadata_file"

  echo "iterative-improve gate uninstalled from $project_root"
  echo "The .gitignore entry and .scratch/agent-state/ are left in place intentionally."
}

check_gate() {
  local installed latest
  require_jq
  installed=$(installed_version)
  latest=$(latest_version)

  echo "installed: $installed"
  echo "latest:    $latest"
  if [ "$installed" = "$latest" ]; then
    echo "update:    not needed"
  else
    echo "update:    available"
  fi
}

print_version() {
  echo "installer: $(source_version)"
  if [ -f "$metadata_file" ]; then
    echo "installed: $(installed_version)"
  fi
}

case "${1:-}" in
  "")
    mode="install"
    ;;
  --update)
    mode="update"
    ;;
  --check)
    mode="check"
    ;;
  --version)
    mode="version"
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

case "$mode" in
  install|update)
    install_gate
    ;;
  check)
    check_gate
    ;;
  version)
    print_version
    ;;
  uninstall)
    uninstall_gate
    ;;
esac
