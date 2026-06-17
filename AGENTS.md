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
- Writes `.claude/iterative-improve.json` install metadata.
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

## Update Commands

Check for updates:

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash -s -- --check
```

Update the project hook:

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash -s -- --update
```

Show installer and installed versions:

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash -s -- --version
```

Pin a release, branch, or commit:

```bash
ITERATIVE_IMPROVE_REF=v0.3.3 \
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/v0.3.3/install.sh | bash
```

Do not add automatic silent updates. The gate changes execution behavior, so updates must be explicit.

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

## Optional PermissionRequest Auto-Approve

Do not bundle, install, copy, vendor, or reimplement third-party `PermissionRequest` auto-approve hooks in this project. Auto-approving Claude Code's `ExitPlanMode` permission dialog is a companion integration, not part of the required iterative-improve gate.

The installer must manage only this project's `UserPromptSubmit` and `PreToolUse` hook registrations. If a target project already has a `PermissionRequest` hook, preserve it. If users choose a third-party auto-approve hook, tell them to install it separately and keep its license and attribution intact.

When both hook types are present, `PreToolUse` remains the source of iterative-improve validation. `PermissionRequest` may approve Claude Code's dialog only after the gate has allowed `ExitPlanMode`.

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
| `ITERATIVE_IMPROVE_TRIGGER_REGEX` | Strict line-based command regex for `/iterative-improve`, `循环优化`, and `iterative improvement` | Prompts that activate the gate |
| `ITERATIVE_IMPROVE_RESET_REGEX` | English and Chinese reset phrases | Prompts that reset the gate |

Default trigger behavior is intentionally narrow. The gate activates only when at least one trimmed prompt line matches one of these command forms:

- `/iterative-improve`
- `/iterative-improve <topic>`
- `循环优化`
- `循环优化: <topic>`
- `循环优化：<topic>`
- `iterative improvement`
- `iterative improvement: <topic>`

Do not treat repository URLs, installation prompts, documentation quotes, or ordinary mentions of `iterative-improve` as activation signals.

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

The installer writes version metadata to:

```text
.claude/iterative-improve.json
```

This file records the repository, ref, raw URL, installed version, install time, hook path, and settings path.

The installer and gate create the primary artifact directories, `plans/` and `results/`, by default. Agents should write the actual gate plan to `plans/*.md` and name the future result artifact as `results/*.md` unless project configuration overrides `ITERATIVE_IMPROVE_PLAN_DIRS` or `ITERATIVE_IMPROVE_RESULT_DIRS`.

Reset the gate:

```bash
bash .claude/hooks/iterative-improve-gate.sh --reset
```

`--reset` may be run from the main worktree or any linked worktree. The hook clears gate state across the detected Git worktree group.

Manual reset fallback:

```bash
rm -f .scratch/agent-state/iterative-improve-gate.json .scratch/agent-state/last-approved-plan.md
```

## Plan Requirements

When `/iterative-improve` is active, `ExitPlanMode` must provide or point to a plan containing:

- Goal or objective.
- Round or iteration.
- For round 1, an explicit statement that no previous result exists.
- For round 2 and later, a `Previous Result Analysis` section that cites the previous result file path and explains how it drives the next plan.
- Worktree or branch isolation.
- Verification or tests.
- A concrete result file path under one configured result directory.
- Commit step.
- Merge step.
- Cleanup step.

The hook accepts English or Chinese wording for these concepts.

At `ExitPlanMode`, the hook checks that the plan file exists in a configured plan directory and that the plan names the future result file path. It does not require the future result file to exist yet. For round 2 and later, the hook also requires previous-result analysis and a previous result file path.

If no active gate is present to enforce these requirements, stop before implementation.

## Expected Loop

The agent should run one round at a time:

1. Detect the iterative-improve request.
2. Verify that the gate hook is installed and registered, or install it before continuing.
3. Activate the gate through the trigger prompt or project entrypoint.
4. Read project instructions such as `AGENTS.md`, `CLAUDE.md`, README files, CI config, and scripts.
5. For round 2 and later, read the latest result file before planning.
6. Write a plan file in one of the configured plan directories. The plan must either declare round 1 has no previous result or analyze the previous result file.
7. Exit planning only when the gate accepts a plan containing all required items.
8. Create and enter the planned worktree or branch.
9. Implement only the planned round.
10. Verify with real commands and capture outcomes.
11. Write a result artifact with a `Next Round Handoff` section.
12. Commit the round.
13. Merge back according to project rules.
14. Clean up the worktree or branch.
15. Reset gate state or start the next round intentionally.

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
