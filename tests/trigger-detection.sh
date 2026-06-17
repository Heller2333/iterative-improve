#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_HOOK="$ROOT/scripts/claude-code-gate.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

make_project() {
  local name="$1"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir/.claude/hooks"
  cp "$SOURCE_HOOK" "$dir/.claude/hooks/iterative-improve-gate.sh"
  chmod +x "$dir/.claude/hooks/iterative-improve-gate.sh"
  printf '%s\n' "$dir"
}

run_prompt() {
  local dir="$1"
  local prompt="$2"
  local payload
  payload=$(jq -n \
    --arg prompt "$prompt" \
    --arg session_id "test-session" \
    '{hook_event_name: "UserPromptSubmit", prompt: $prompt, session_id: $session_id}')
  printf '%s' "$payload" | "$dir/.claude/hooks/iterative-improve-gate.sh" >/dev/null
}

state_exists() {
  local dir="$1"
  [ -f "$dir/.scratch/agent-state/iterative-improve-gate.json" ]
}

assert_triggered() {
  local prompt="$1"
  local dir
  dir=$(make_project "trigger-$(date +%s%N)")
  run_prompt "$dir" "$prompt"
  if ! state_exists "$dir"; then
    echo "Expected prompt to activate gate, but it did not:"
    printf '%s\n' "$prompt"
    exit 1
  fi
}

assert_not_triggered() {
  local prompt="$1"
  local dir
  dir=$(make_project "no-trigger-$(date +%s%N)")
  run_prompt "$dir" "$prompt"
  if state_exists "$dir"; then
    echo "Expected prompt not to activate gate, but it did:"
    printf '%s\n' "$prompt"
    exit 1
  fi
}

assert_triggered "/iterative-improve"
assert_triggered "/iterative-improve reduce flaky output"
assert_triggered "循环优化"
assert_triggered "循环优化：减少噪音输出"
assert_triggered "iterative improvement"
assert_triggered "iterative improvement: reduce flaky output"

assert_not_triggered "Install https://github.com/Heller2333/iterative-improve in this project."
assert_not_triggered "Please review iterative-improve before we decide whether to install it."
assert_not_triggered "The README shows /iterative-improve as an example command."
assert_not_triggered "https://github.com/Heller2333/iterative-improve"

echo "trigger detection cases passed"
