#!/bin/bash
# Generic Claude Code gate for iterative-improvement loops.
#
# Install this script inside a project as:
#   .claude/hooks/iterative-improve-gate.sh
#
# The script is intentionally generic. Tune behavior with environment variables
# in .claude/settings.json when a project needs stricter local policy.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"

state_dir="${ITERATIVE_IMPROVE_STATE_DIR:-$project_root/.scratch/agent-state}"
state_file="$state_dir/iterative-improve-gate.json"
last_plan_file="$state_dir/last-approved-plan.md"

repo_name="$(basename "$project_root")"
plan_dirs="${ITERATIVE_IMPROVE_PLAN_DIRS:-plans .agents/plans reports/plans docs/plans code/reports/plans}"
result_dirs="${ITERATIVE_IMPROVE_RESULT_DIRS:-results .agents/results reports/results docs/results code/reports/results}"
worktree_prefix="${ITERATIVE_IMPROVE_WORKTREE_PREFIX:-$repo_name-improve-}"
worktree_prefixes="${ITERATIVE_IMPROVE_WORKTREE_PREFIXES:-$worktree_prefix $repo_name-opt-}"
branch_regex="${ITERATIVE_IMPROVE_BRANCH_REGEX:-improve/[[:alnum:]_./-]+|iter/[[:alnum:]_./-]+|feature/improve[-/][[:alnum:]_./-]+|codex/improve[-/][[:alnum:]_./-]+|opt/[[:alnum:]_./-]+|feature/opt[-/][[:alnum:]_./-]+|codex/opt[-/][[:alnum:]_./-]+}"
trigger_regex="${ITERATIVE_IMPROVE_TRIGGER_REGEX:-/iterative-improve|开始循环优化|按[[:space:]]*反馈优化|按[[:space:]]*Codex[[:space:]]*反馈优化|循环优化|迭代优化|持续改进|automatic iterative improvement|iterative improvement loop}"
reset_regex="${ITERATIVE_IMPROVE_RESET_REGEX:-退出[[:space:]]*(gate|Gate|循环优化|迭代优化)|关闭[[:space:]]*(gate|Gate|循环优化|迭代优化)|取消循环优化|停止循环优化|重置[[:space:]]*(gate|Gate|循环优化)|reset[[:space:]]+(gate|iterative[[:space:]]+improve|optimization[[:space:]]+gate)}"

reset_state() {
  rm -f "$state_file" "$last_plan_file" "$state_file.tmp"
  rmdir "$state_dir" "$project_root/.scratch" 2>/dev/null || true
}

if [ "${1:-}" = "--reset" ]; then
  reset_state
  echo "iterative-improve gate reset"
  exit 0
fi

input=$(cat)

event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

deny_pretool() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

user_context() {
  local title="$1"
  local context="$2"
  jq -n --arg title "$title" --arg context "$context" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      sessionTitle: $title,
      additionalContext: $context
    }
  }'
}

is_active() {
  [ -f "$state_file" ] && [ "$(jq -r '.active // false' "$state_file" 2>/dev/null)" = "true" ]
}

state_value() {
  jq -r '.state // empty' "$state_file" 2>/dev/null
}

write_state() {
  local state="$1"
  local session_id="$2"
  local prompt="$3"
  mkdir -p "$state_dir"
  jq -n \
    --arg state "$state" \
    --arg session_id "$session_id" \
    --arg prompt "$prompt" \
    --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{active: true, state: $state, session_id: $session_id, trigger_prompt: $prompt, created_at: $created_at}' \
    > "$state_file"
}

approve_plan_state() {
  local plan_file="$1"
  local plan_text="$2"
  mkdir -p "$state_dir"
  if [ -f "$state_file" ]; then
    jq \
      --arg state "plan_approved" \
      --arg plan_file "$plan_file" \
      --arg approved_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '.state = $state | .plan_file = $plan_file | .plan_approved_at = $approved_at' \
      "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
  else
    jq -n \
      --arg state "plan_approved" \
      --arg plan_file "$plan_file" \
      --arg approved_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{active: true, state: $state, plan_file: $plan_file, plan_approved_at: $approved_at}' \
      > "$state_file"
  fi

  printf '%s' "$plan_text" > "$last_plan_file"
}

latest_plan_file() {
  local dir
  for dir in $plan_dirs; do
    find "$project_root/$dir" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null
  done | xargs -0 ls -t 2>/dev/null | sed -n '1p'
}

resolve_plan_file() {
  local candidate="$1"
  local resolved

  if [ -n "$candidate" ]; then
    case "$candidate" in
      /*)
        resolved="$candidate"
        ;;
      *)
        resolved="$project_root/$candidate"
        ;;
    esac

    if [ -f "$resolved" ] && is_plan_file "$resolved"; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  latest_plan_file
}

main_worktree() {
  git -C "$project_root" worktree list --porcelain 2>/dev/null \
    | awk 'NR == 1 && $1 == "worktree" {print $2}'
}

is_main_worktree() {
  local repo_root main_root
  repo_root=""
  [ -n "$cwd" ] && repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
  main_root=$(main_worktree)
  [ -n "$repo_root" ] && [ -n "$main_root" ] && [ "$repo_root" = "$main_root" ]
}

is_plan_file() {
  local path="$1"
  local dir
  for dir in $plan_dirs; do
    case "$path" in
      "$project_root/$dir"/*.md|"$dir"/*.md)
        return 0
        ;;
    esac
  done
  return 1
}

regex_escape() {
  printf '%s' "$1" | sed 's/[][\/.^$*+?(){}|]/\\&/g'
}

worktree_prefix_regex() {
  local prefix escaped joined
  joined=""
  for prefix in $worktree_prefixes; do
    escaped=$(regex_escape "$prefix")
    if [ -z "$joined" ]; then
      joined="$escaped"
    else
      joined="$joined|$escaped"
    fi
  done
  printf '%s' "$joined"
}

is_readonly_bash() {
  local cmd
  cmd=$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])(rm|mv|cp|touch|chmod|chown|ln|python|python3|uv|pip|pytest|streamlit|git[[:space:]]+(add|commit|merge|push|checkout|switch|reset|clean|branch[[:space:]]+-D|worktree[[:space:]]+(add|remove)))\b'; then
    return 1
  fi

  case "$cmd" in
    ""|pwd|ls|ls\ *|rg\ *|grep\ *|sed\ -n\ *|cat\ *|head\ *|tail\ *|wc\ *|find\ *|jq\ *|ps\ *|command\ -v\ *|which\ *|git\ status*|git\ branch\ --show-current*|git\ worktree\ list*|git\ diff*|git\ log*|git\ show*|git\ ls-files*)
      if printf '%s' "$cmd" | grep -Eq 'find .* -delete|>[>|]?|tee '; then
        return 1
      fi
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_gate_command() {
  printf '%s' "$1" \
    | sed 's/[[:space:]]*2>&1//g' \
    | sed 's/[[:space:]]*&&[[:space:]]*echo[[:space:]][[:space:]]*.*$//' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

is_reset_command() {
  local cmd script_path
  cmd=$(normalize_gate_command "$1")
  script_path="$project_root/.claude/hooks/iterative-improve-gate.sh"

  case "$cmd" in
    "bash .claude/hooks/iterative-improve-gate.sh --reset"|"./.claude/hooks/iterative-improve-gate.sh --reset"|"bash $script_path --reset"|"$script_path --reset")
      return 0
      ;;
  esac

  printf '%s' "$cmd" | grep -Eq '^rm[[:space:]]+-f[[:space:]]+(\.scratch/agent-state/iterative-improve-gate\.json|'"$state_file"')([[:space:]]+(\.scratch/agent-state/last-approved-plan\.md|'"$last_plan_file"'))*[[:space:]]*$'
}

is_cleanup_command() {
  local cmd wt br merge reset wt_prefix_regex
  cmd=$(normalize_gate_command "$1")
  wt_prefix_regex=$(worktree_prefix_regex)

  wt='git[[:space:]]+worktree[[:space:]]+remove[[:space:]]+((\.\./)?('"$wt_prefix_regex"')[[:alnum:]_.-]+|/[^[:space:]]*/('"$wt_prefix_regex"')[[:alnum:]_.-]+)'
  br='git[[:space:]]+branch[[:space:]]+-d[[:space:]]+('"$branch_regex"')'
  merge='git[[:space:]]+merge[[:space:]]+(--no-edit[[:space:]]+)?('"$branch_regex"')([[:space:]]+--no-edit)?'
  reset='rm[[:space:]]+-f[[:space:]]+(\.scratch/agent-state/iterative-improve-gate\.json|'"$state_file"')([[:space:]]+(\.scratch/agent-state/last-approved-plan\.md|'"$last_plan_file"'))*'

  printf '%s' "$cmd" | grep -Eq "^($merge|$wt|$br|$reset)$|^$merge[[:space:]]*&&[[:space:]]*$wt[[:space:]]*&&[[:space:]]*$br([[:space:]]*&&[[:space:]]*$reset)?$|^$wt[[:space:]]*&&[[:space:]]*$br([[:space:]]*&&[[:space:]]*$reset)?$|^$wt[[:space:]]*&&[[:space:]]*$reset$|^$br[[:space:]]*&&[[:space:]]*$reset$|^git[[:space:]]+worktree[[:space:]]+prune$"
}

plan_has_result_path() {
  local plan="$1"
  local dir escaped

  for dir in $result_dirs; do
    escaped=$(regex_escape "$dir")
    if printf '%s' "$plan" | grep -Eq "(^|[^[:alnum:]_./-])$escaped/[^[:space:]'\"\`)]+\.md([^[:alnum:]_.-]|$)"; then
      return 0
    fi
  done

  return 1
}

plan_missing_reason() {
  local plan="$1"
  local missing=()

  printf '%s' "$plan" | grep -Eiq 'goal|objective|success criteria|目标|主题' || missing+=("goal/objective")
  printf '%s' "$plan" | grep -Eiq 'round|iteration|轮次|R[0-9]+' || missing+=("round")
  printf '%s' "$plan" | grep -Eiq 'worktree|branch|隔离|分支' || missing+=("worktree/branch isolation")
  printf '%s' "$plan" | grep -Eiq 'verify|test|validation|验证|测试' || missing+=("verification")
  printf '%s' "$plan" | grep -Eiq 'result|report|结果|报告' || missing+=("result artifact")
  plan_has_result_path "$plan" || missing+=("concrete result file path")
  printf '%s' "$plan" | grep -Eiq 'commit|提交' || missing+=("commit")
  printf '%s' "$plan" | grep -Eiq 'merge|合并' || missing+=("merge")
  printf '%s' "$plan" | grep -Eiq 'cleanup|worktree remove|清理|删除 worktree' || missing+=("cleanup")

  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'ExitPlanMode denied: iterative-improve plan is missing: %s. Update the plan file and try again.' "$(IFS=', '; echo "${missing[*]}")"
    return 0
  fi

  return 1
}

if [ "$event" = "UserPromptSubmit" ]; then
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

  if printf '%s' "$prompt" | grep -Eiq "$reset_regex"; then
    reset_state
    user_context "iterative-improve gate reset" "The iterative-improve gate has been reset. Stop the loop unless the user explicitly starts a new one."
    exit 0
  fi

  if printf '%s' "$prompt" | grep -Eiq "$trigger_regex"; then
    write_state "loop_pending_plan" "$session_id" "$prompt"
    user_context "iterative-improve gate" "An iterative-improve request was detected. Before mutating files, enter/perform a read-only planning phase, inspect local project rules, write a plan file, and pass ExitPlanMode if available. The plan must include goal, round, worktree/branch isolation, verification, a concrete result file path under a configured result directory, commit, merge, and cleanup."
  fi

  exit 0
fi

if ! is_active; then
  exit 0
fi

command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
gate_state=$(state_value)

if [ "$event" = "PreToolUse" ]; then
  if [ "$tool_name" = "Bash" ] && is_reset_command "$command"; then
    exit 0
  fi

  if [ "$tool_name" = "ExitPlanMode" ]; then
    plan=$(printf '%s' "$input" | jq -r '.tool_input.plan // empty' 2>/dev/null)
    plan_file=$(printf '%s' "$input" | jq -r '.tool_input.planFilePath // empty' 2>/dev/null)
    resolved_plan_file=$(resolve_plan_file "$plan_file")

    if [ -z "$resolved_plan_file" ]; then
      deny_pretool "ExitPlanMode denied: no plan file was found in configured plan directories."
      exit 0
    fi

    plan_file="$resolved_plan_file"

    if [ -z "$plan" ]; then
        plan=$(cat "$resolved_plan_file")
    fi

    if reason=$(plan_missing_reason "$plan"); then
      deny_pretool "$reason"
      exit 0
    fi

    approve_plan_state "$plan_file" "$plan"
    exit 0
  fi

  if [ "$gate_state" != "plan_approved" ]; then
    case "$tool_name" in
      Edit|Write)
        if is_plan_file "$file_path"; then
          exit 0
        fi
        deny_pretool "iterative-improve gate: before plan approval, only plan files may be written."
        exit 0
        ;;
      Bash)
        if is_readonly_bash "$command"; then
          exit 0
        fi
        deny_pretool "iterative-improve gate: before plan approval, only read-only exploration commands are allowed."
        exit 0
        ;;
    esac
  fi

  if [ "$gate_state" = "plan_approved" ] && is_main_worktree; then
    case "$tool_name" in
      Edit|Write)
        deny_pretool "iterative-improve gate: plan is approved, but this is the main worktree. Create and enter the planned worktree before editing code."
        exit 0
        ;;
      Bash)
        if is_readonly_bash "$command" || is_cleanup_command "$command" || printf '%s' "$command" | grep -Eq 'git[[:space:]]+worktree[[:space:]]+add'; then
          exit 0
        fi
        deny_pretool "iterative-improve gate: in the main worktree, only read-only checks, git worktree add, and restricted merge/cleanup commands are allowed."
        exit 0
        ;;
    esac
  fi
fi

exit 0
