#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_HOOK="$ROOT/scripts/claude-code-gate.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

contains_deny() {
  printf '%s' "$1" | grep -Eq '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'
}

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
  local session_id="${3:-test-session}"
  local payload
  payload=$(jq -n \
    --arg prompt "$prompt" \
    --arg session_id "$session_id" \
    '{hook_event_name: "UserPromptSubmit", prompt: $prompt, session_id: $session_id}')
  printf '%s' "$payload" | "$dir/.claude/hooks/iterative-improve-gate.sh" >/dev/null
}

state_exists() {
  local dir="$1"
  [ -d "$dir/.scratch/agent-state" ] && find "$dir/.scratch/agent-state" -maxdepth 1 -type f -name 'iterative-improve-gate*.json' | grep -q .
}

run_pretool_write() {
  local dir="$1"
  local file_path="$2"
  local session_id="$3"
  local payload
  payload=$(jq -n \
    --arg cwd "$dir" \
    --arg file_path "$file_path" \
    --arg session_id "$session_id" \
    '{
      hook_event_name: "PreToolUse",
      tool_name: "Write",
      cwd: $cwd,
      session_id: $session_id,
      tool_input: {file_path: $file_path}
    }')
  printf '%s' "$payload" | "$dir/.claude/hooks/iterative-improve-gate.sh"
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

session_dir=$(make_project "session-isolation")
run_prompt "$session_dir" "/iterative-improve improve reports" "session-a"

other_session_output=$(run_pretool_write "$session_dir" "results/from-other-session.md" "session-b")
if contains_deny "$other_session_output"; then
  echo "Expected a different session to bypass the active gate, but it was denied."
  exit 1
fi

same_session_output=$(run_pretool_write "$session_dir" "results/from-same-session.md" "session-a")
if ! contains_deny "$same_session_output"; then
  echo "Expected the triggering session to remain gated before plan approval, but it was allowed."
  exit 1
fi

run_prompt "$session_dir" "/iterative-improve improve ingestion" "session-b"
same_session_output_after_second_activation=$(run_pretool_write "$session_dir" "results/from-same-session-after-second-activation.md" "session-a")
if ! contains_deny "$same_session_output_after_second_activation"; then
  echo "Expected the first session to stay gated after a second session activated the gate, but it was allowed."
  exit 1
fi

echo "trigger detection cases passed"
