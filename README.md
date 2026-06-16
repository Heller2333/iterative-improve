# iterative-improve

English | [中文](README.zh-CN.md)

A gate-enforced Agent Skill for iterative coding work: activate a gate, plan first, isolate risky changes, verify with real commands, record results, commit deliberately, merge, clean up, and only then continue.

It is repository-agnostic. Use it for refactors, migrations, strategy experiments, report pipelines, data workflows, quality loops, and any task where an AI coding agent should improve in controlled rounds instead of drifting.

## Quick Start

Tell your AI coding agent:

> "Clone https://github.com/Heller2333/iterative-improve into this project. Install the iterative-improve skill for my coding agent and set up the required Claude Code gate hooks so iterative-improve requests must plan first, use worktree or branch isolation, verify changes, write result artifacts, commit, merge, and clean up. Read the AGENTS.md for the full technical reference on how everything works."

The agent will:

1. Clone this repository into the current project, usually as `.iterative-improve/`.
2. Install `SKILL.md` into your agent's skills directory.
3. Copy `scripts/claude-code-gate.sh` into `.claude/hooks/`.
4. Merge the required hook configuration into `.claude/settings.json`.
5. Refuse to run `/iterative-improve` implementation steps if the gate cannot be installed or activated.

After that, start a loop with:

```text
Use /iterative-improve to improve the report generation pipeline.
Goal: reduce noisy output and improve verification.
Max rounds: 3.
```

Chinese prompts also work:

```text
使用 /iterative-improve 对数据处理模块做循环优化。
目标：提升稳定性和可验证性。
最多 3 轮。
```

## How It Works

```text
Trigger prompt
  -> read project rules
  -> activate required gate
  -> plan one round
  -> approve/exit planning
  -> create isolated worktree or branch
  -> implement the planned change
  -> verify with real commands
  -> write result artifact
  -> commit, merge, clean up
  -> decide whether to continue
```

- `SKILL.md` teaches the agent the iterative workflow.
- `scripts/claude-code-gate.sh` is the required Claude Code gate hook for this workflow.
- The gate stores temporary state under `.scratch/agent-state/` in the target project.
- The gate is generic and configurable with environment variables; project-specific policy should live in the target project's own instructions.

## Mandatory Gate Contract

When this skill is used, the workflow must run under a gate. In Claude Code, install and enable `scripts/claude-code-gate.sh`. In other environments, use an equivalent enforcement mechanism before any mutating work.

The gate blocks:

- Code edits before a plan exists.
- Execution before the plan is approved.
- Editing in the main worktree after approval.
- Unsafe merge or cleanup commands outside allowed optimization branch/worktree patterns.
- Exiting Plan Mode when the plan is missing key items such as goal, round, worktree or branch isolation, verification, result artifact, commit, merge, and cleanup.

If the gate cannot be installed or activated, the agent may inspect files and explain the missing setup, but must not continue into iterative-improvement implementation.

## Manual Installation

### Codex

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.codex/skills/iterative-improve
```

Update later:

```bash
git -C ~/.codex/skills/iterative-improve pull
```

### Claude Code

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.claude/skills/iterative-improve
```

Update later:

```bash
git -C ~/.claude/skills/iterative-improve pull
```

### Required Claude Code Hook

From a target project:

```bash
mkdir -p .claude/hooks
cp ~/.codex/skills/iterative-improve/scripts/claude-code-gate.sh .claude/hooks/iterative-improve-gate.sh
chmod +x .claude/hooks/iterative-improve-gate.sh
```

Then add the hooks shown in [AGENTS.md](AGENTS.md) to `.claude/settings.json`.

Reset the gate when you need to cancel a loop:

```bash
bash .claude/hooks/iterative-improve-gate.sh --reset
```

## Key Files

```text
iterative-improve/
├── SKILL.md                       # Agent Skill body
├── AGENTS.md                      # Technical reference for coding agents
├── README.md                      # English documentation
├── README.zh-CN.md                # Chinese documentation
├── scripts/
│   └── claude-code-gate.sh        # Required Claude Code gate hook template
└── LICENSE                        # MIT License
```

## Technical Reference

See [AGENTS.md](AGENTS.md) for hook configuration, installation details, environment variables, state files, plan requirements, and troubleshooting notes.

## Privacy

This repository is designed for public use. It does not include private project paths, credentials, API keys, data files, or personal workflow state. Before publishing changes, scan for local paths and secrets.

## License

MIT. See [LICENSE](LICENSE).
