# iterative-improve Technical Reference

This file is for AI coding agents that install or maintain this repository inside another project.

## Goal

Install a reusable iterative-improvement workflow with two layers:

1. `SKILL.md`: portable agent instructions.
2. `scripts/claude-code-gate.sh`: required Claude Code hook enforcement.

Keep this repository generic. Do not add project-specific paths, credentials, private data directories, or local workflow state.

## One-Shot Install In A Target Project

From the target project root:

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash
```

Or from a local clone:

```bash
git clone https://github.com/Heller2333/iterative-improve.git /tmp/iterative-improve
bash /tmp/iterative-improve/install.sh
```

The installer modifies only the current project:

- Creates `.claude/hooks/iterative-improve-gate.sh`.
- Backs up and merges `.claude/settings.json`.
- Appends `.scratch/agent-state/` to `.gitignore` if needed.
- Stops if `jq` is missing.
- Stops if `.claude/settings.json` is invalid JSON.

The installer does not write global `~/.claude` or `~/.codex` configuration.

## Optional Skill Directory Install

If the coding environment also needs a local skill copy, install the skill for Codex:

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.codex/skills/iterative-improve
```

Or install for Claude Code if that environment uses `~/.claude/skills`:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.claude/skills/iterative-improve
```

Do not mark project setup complete until the project-level gate hook is installed and registered.

If the gate cannot be installed, report the blocker and do not run iterative-improvement implementation steps.

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

The hook registration is mandatory for Claude Code usage. Without it, `/iterative-improve` may be used only to inspect the repository and explain the missing setup; it must not proceed to code edits, experiments, commits, merges, or cleanup.

## Configurable Environment Variables

Set these in the hook command or the shell environment when the project needs different conventions. These variables are optional configuration; the gate itself is not optional.

| Variable | Default | Purpose |
| --- | --- | --- |
| `ITERATIVE_IMPROVE_STATE_DIR` | `.scratch/agent-state` under the project root | Gate state location |
| `ITERATIVE_IMPROVE_PLAN_DIRS` | `plans .agents/plans reports/plans docs/plans code/reports/plans` | Directories searched for plan files |
| `ITERATIVE_IMPROVE_RESULT_DIRS` | `results .agents/results reports/results docs/results code/reports/results` | Directories allowed for planned result files |
| `ITERATIVE_IMPROVE_WORKTREE_PREFIX` | `<repo-name>-improve-` | Primary worktree path prefix |
| `ITERATIVE_IMPROVE_WORKTREE_PREFIXES` | `<repo-name>-improve- <repo-name>-opt-` | Allowed cleanup worktree path prefixes |
| `ITERATIVE_IMPROVE_BRANCH_REGEX` | `improve/*`, `iter/*`, `feature/improve-*`, `codex/improve-*`, plus `opt/*` compatibility patterns | Allowed iterative-improvement branch names |
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

When `/iterative-improve` is active, `ExitPlanMode` must provide or point to a plan containing:

- Goal or objective.
- Round or iteration.
- Worktree or branch isolation.
- Verification or tests.
- A concrete result file path under one configured result directory.
- Commit step.
- Merge step.
- Cleanup step.

The hook accepts English or Chinese wording for these concepts.

At `ExitPlanMode`, the hook checks that the plan file exists in a configured plan directory and that the plan names the future result file path. It does not require the result file to exist yet.

If no active gate is present to enforce these requirements, stop before implementation.

## Expected Loop

The agent should run one round at a time:

1. Detect the iterative-improve request.
2. Verify that the gate hook is installed and registered, or install it before continuing.
3. Activate the gate through the trigger prompt or project entrypoint.
4. Read project instructions such as `AGENTS.md`, `CLAUDE.md`, README files, CI config, and scripts.
5. Write a plan file in one of the configured plan directories.
6. Exit planning only when the gate accepts a plan containing all required items.
7. Create and enter the planned worktree or branch.
8. Implement only the planned round.
9. Verify with real commands and capture outcomes.
10. Write a result artifact.
11. Commit the round.
12. Merge back according to project rules.
13. Clean up the worktree or branch.
14. Reset gate state or start the next round intentionally.

## Troubleshooting

If the gate blocks `ExitPlanMode`, update the plan so it includes all required concepts, or make sure the plan was written to a configured plan directory.

If the gate blocks edits after plan approval, check whether the agent is still in the main worktree. Create and enter the planned worktree or branch.

If merge or cleanup is blocked, check the branch name and worktree path against `ITERATIVE_IMPROVE_BRANCH_REGEX` and `ITERATIVE_IMPROVE_WORKTREE_PREFIX`.

If a loop was started accidentally, run:

```bash
bash .claude/hooks/iterative-improve-gate.sh --reset
```

If the hook was never installed, install it before starting or resuming the loop. Do not substitute a verbal promise to follow the process.

Uninstall the project hook:

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash -s -- --uninstall
```

Uninstall removes the hook command from `.claude/settings.json` and deletes `.claude/hooks/iterative-improve-gate.sh`. It intentionally leaves `.gitignore` and `.scratch/agent-state/` alone.

## Validation Before Publishing Changes

Run these checks in this repository:

```bash
bash -n scripts/claude-code-gate.sh
bash -n install.sh
python3 path/to/skill-creator/scripts/quick_validate.py .
```

If the validator path does not exist, use the validator bundled with your agent environment or manually verify that `SKILL.md` has valid YAML frontmatter with `name` and `description`.

Before publishing, scan for local paths, credentials, private data directories, and workflow state with the target environment's preferred secret scanner.
