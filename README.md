# iterative-improve

English | [中文](README.zh-CN.md)

`iterative-improve` is a generic, gate-aware Agent Skill for iterative coding workflows. It helps an agent discover local project rules, plan one round at a time, isolate risky work in a worktree, execute, verify, review, record results, and safely continue or stop.

It is intentionally repository-agnostic: it does not assume a specific project, metric, branch name, directory layout, or tool vendor.

## What It Does

The skill guides an agent through a controlled loop:

1. Discover local project rules and gates.
2. Write a plan before mutating files.
3. Use project-required isolation, such as a Git worktree.
4. Implement only the current round's planned change.
5. Verify with real commands and real outputs.
6. Review the result and record findings.
7. Decide whether to continue, pivot, or stop.

It is useful for refactors, migrations, strategy experiments, report pipelines, data workflows, quality loops, and other tasks where "just keep fixing" tends to produce messy agent behavior.

## Installation

### Codex

Clone this repository directly into your Codex skills directory:

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.codex/skills/iterative-improve
```

Update later with:

```bash
git -C ~/.codex/skills/iterative-improve pull
```

This installs the Markdown skill. The optional shell gate script remains available inside the cloned repository under `scripts/`.

### Claude Code

Clone this repository into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.claude/skills/iterative-improve
```

Update later with:

```bash
git -C ~/.claude/skills/iterative-improve pull
```

This installs the Markdown skill. To enforce the workflow with Claude Code hooks, see [Optional Claude Code Gate](#optional-claude-code-gate).

### Manual Copy

Copy the repository folder into any skills directory supported by your agent:

```bash
cp -R iterative-improve ~/.codex/skills/iterative-improve
```

## Optional Claude Code Gate

The skill can be used as Markdown-only guidance. If you want tool-call enforcement, this repository also ships a generic Claude Code hook template:

```text
scripts/claude-code-gate.sh
```

Install it inside a project:

```bash
mkdir -p .claude/hooks
cp ~/.codex/skills/iterative-improve/scripts/claude-code-gate.sh .claude/hooks/iterative-improve-gate.sh
chmod +x .claude/hooks/iterative-improve-gate.sh
```

Add it to the project's `.claude/settings.json`:

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

Reset the gate when you need to cancel a loop:

```bash
bash .claude/hooks/iterative-improve-gate.sh --reset
```

The script is configurable with environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `ITERATIVE_IMPROVE_PLAN_DIRS` | `plans reports/plans code/reports/plans` | Directories searched for plan files |
| `ITERATIVE_IMPROVE_WORKTREE_PREFIX` | `<repo-name>-opt-` | Allowed worktree path prefix |
| `ITERATIVE_IMPROVE_BRANCH_REGEX` | `opt/*`, `feature/opt-*`, `codex/opt-*` | Allowed optimization branch patterns |
| `ITERATIVE_IMPROVE_TRIGGER_REGEX` | English and Chinese iterative-improve trigger phrases | Prompts that activate the gate |
| `ITERATIVE_IMPROVE_RESET_REGEX` | English and Chinese reset phrases | Prompts that reset the gate |

Keep project-specific policy in the target project's instructions. Do not hard-code private paths, credentials, or local data directories into the public script.

## Usage

Ask your agent to use the skill:

```text
Use /iterative-improve to improve the report generation pipeline.
Goal: reduce noisy output and improve verification.
Max rounds: 3.
```

Or:

```text
Start an iterative improvement loop for the authentication module.
Use the existing project rules, write one plan and one result per round, and stop after 2 rounds or when review findings are stable.
```

For Chinese prompts:

```text
使用 /iterative-improve 对数据处理模块做循环优化。
目标：提升稳定性和可验证性。
最多 3 轮。
```

## Expected Project Conventions

The skill does not require a specific project layout. It asks the agent to inspect the local repository first and follow whatever it finds, such as:

- `AGENTS.md`, `CLAUDE.md`, or other agent instructions.
- Project-specific hooks or gates.
- Existing `plans/`, `results/`, or report directories.
- Test commands in README, CI, package metadata, or scripts.
- Git worktree, branch, commit, merge, and cleanup rules.

If a project has stricter local rules than this skill, the local rules win.

## Gate-Aware Behavior

Some projects enforce workflow gates through hooks or wrapper scripts. This skill tells the agent to respect those gates rather than bypassing them.

Examples of gate behavior:

- No code edits before a plan exists.
- No execution until Plan Mode has been exited successfully.
- No edits in the main worktree after a plan is approved.
- No merge or cleanup until verification and result files exist.

If no gate exists, the agent should manually follow the same discipline.

## Repository Structure

```text
iterative-improve/
├── SKILL.md                       # The actual Agent Skill
├── README.md                      # English documentation
├── README.zh-CN.md                # Chinese documentation
├── scripts/
│   └── claude-code-gate.sh        # Optional Claude Code hook template
└── LICENSE                        # MIT License
```

## Privacy

This repository is designed for public use. The skill does not include private project paths, credentials, API keys, data files, or personal workflow state. Before publishing changes, scan for local paths and secrets.

## License

MIT. See [LICENSE](LICENSE).
