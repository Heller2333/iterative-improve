# iterative-improve Technical Reference

This file is for AI coding agents that install or maintain this repository inside another project.

## Goal

Install a reusable iterative-improvement workflow with two layers:

1. `SKILL.md`: portable agent instructions.
2. `scripts/claude-code-gate.sh`: optional Claude Code hook enforcement.

Keep this repository generic. Do not add project-specific paths, credentials, private data directories, or local workflow state.

## One-Shot Install In A Target Project

From the target project root:

```bash
git clone https://github.com/Heller2333/iterative-improve.git .iterative-improve
```

Install the skill for Codex:

```bash
mkdir -p ~/.codex/skills
if [ -d ~/.codex/skills/iterative-improve ]; then
  cp -R .iterative-improve/. ~/.codex/skills/iterative-improve/
else
  cp -R .iterative-improve ~/.codex/skills/iterative-improve
fi
```

Install the skill for Claude Code if that environment uses `~/.claude/skills`:

```bash
mkdir -p ~/.claude/skills
if [ -d ~/.claude/skills/iterative-improve ]; then
  cp -R .iterative-improve/. ~/.claude/skills/iterative-improve/
else
  cp -R .iterative-improve ~/.claude/skills/iterative-improve
fi
```

Install the optional Claude Code gate in the target project:

```bash
mkdir -p .claude/hooks
cp .iterative-improve/scripts/claude-code-gate.sh .claude/hooks/iterative-improve-gate.sh
chmod +x .claude/hooks/iterative-improve-gate.sh
```

If the project should not vendor this repository, remove `.iterative-improve/` after copying the skill and hook.

## Claude Code Hook Configuration

Merge this into the target project's `.claude/settings.json`. Preserve any existing hooks.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/iterative-improve-gate.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/iterative-improve-gate.sh"
          }
        ]
      }
    ]
  }
}
```

If the project already has `UserPromptSubmit` or `PreToolUse` hooks, append this command to the relevant hook arrays rather than replacing existing commands.

## Optional Environment Variables

Set these in the hook command or the shell environment when the project needs different conventions.

| Variable | Default | Purpose |
| --- | --- | --- |
| `ITERATIVE_IMPROVE_STATE_DIR` | `.scratch/agent-state` under the project root | Gate state location |
| `ITERATIVE_IMPROVE_PLAN_DIRS` | `plans reports/plans code/reports/plans` | Directories searched for plan files |
| `ITERATIVE_IMPROVE_WORKTREE_PREFIX` | `<repo-name>-opt-` | Allowed optimization worktree path prefix |
| `ITERATIVE_IMPROVE_BRANCH_REGEX` | `opt/*`, `feature/opt-*`, `codex/opt-*` patterns | Allowed optimization branch names |
| `ITERATIVE_IMPROVE_TRIGGER_REGEX` | English and Chinese iterative-improve trigger phrases | Prompts that activate the gate |
| `ITERATIVE_IMPROVE_RESET_REGEX` | English and Chinese reset phrases | Prompts that reset the gate |

Example hook command with a custom plan directory:

```json
{
  "type": "command",
  "command": "ITERATIVE_IMPROVE_PLAN_DIRS=\"docs/plans reports/plans\" \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/iterative-improve-gate.sh"
}
```

## Gate State

The hook writes temporary state to:

```text
.scratch/agent-state/iterative-improve-gate.json
.scratch/agent-state/last-approved-plan.md
```

These files are local workflow state. They should normally be gitignored by the target project.

Reset the gate:

```bash
bash .claude/hooks/iterative-improve-gate.sh --reset
```

Manual reset fallback:

```bash
rm -f .scratch/agent-state/iterative-improve-gate.json .scratch/agent-state/last-approved-plan.md
```

## Plan Requirements

When the gate is active, `ExitPlanMode` must provide or point to a plan containing:

- Goal or objective.
- Round or iteration.
- Worktree or branch isolation.
- Verification or tests.
- Result artifact.
- Commit step.
- Merge step.
- Cleanup step.

The hook accepts English or Chinese wording for these concepts.

## Expected Loop

The agent should run one round at a time:

1. Detect the iterative-improve request.
2. Read project instructions such as `AGENTS.md`, `CLAUDE.md`, README files, CI config, and scripts.
3. Write a plan file in one of the configured plan directories.
4. Exit planning only when the plan includes all required items.
5. Create and enter the planned worktree or branch.
6. Implement only the planned round.
7. Verify with real commands and capture outcomes.
8. Write a result artifact.
9. Commit the round.
10. Merge back according to project rules.
11. Clean up the worktree or branch.
12. Reset gate state or start the next round intentionally.

## Troubleshooting

If the gate blocks `ExitPlanMode`, update the plan so it includes all required concepts, or make sure the plan was written to a configured plan directory.

If the gate blocks edits after plan approval, check whether the agent is still in the main worktree. Create and enter the planned worktree or branch.

If merge or cleanup is blocked, check the branch name and worktree path against `ITERATIVE_IMPROVE_BRANCH_REGEX` and `ITERATIVE_IMPROVE_WORKTREE_PREFIX`.

If a loop was started accidentally, run:

```bash
bash .claude/hooks/iterative-improve-gate.sh --reset
```

## Validation Before Publishing Changes

Run these checks in this repository:

```bash
bash -n scripts/claude-code-gate.sh
python3 path/to/skill-creator/scripts/quick_validate.py .
```

If the validator path does not exist, use the validator bundled with your agent environment or manually verify that `SKILL.md` has valid YAML frontmatter with `name` and `description`.

Before publishing, scan for local paths, credentials, private data directories, and workflow state with the target environment's preferred secret scanner.
