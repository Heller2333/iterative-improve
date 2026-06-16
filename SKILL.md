---
name: iterative-improve
description: Run a guarded iterative improvement loop for a project, module, strategy, report pipeline, or product workflow. Use when the user says "/iterative-improve", "迭代优化", "循环优化", "持续改进", "自动循环改进", "按反馈优化", or asks an agent to repeatedly plan, implement, verify, review, and continue across rounds while respecting project gates, Plan Mode, worktrees, commits, and result artifacts.
---

# Iterative Improve

Run a controlled loop: **discover rules → plan → implement → verify → review → write result → choose next round**.

This skill is generic. Do not hard-code one repository, metric, tool, branch name, directory layout, or Claude/Codex feature. Discover project rules from local files and use available gates/hooks when present.

## 0. Discover The Local Contract

Before the first round, inspect local sources of truth:

- Agent instructions: `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, docs under `docs/agents/` when present.
- Existing iteration artifacts: `plans/`, `results/`, `reports/`, or module/repository-specific equivalents.
- Verification commands from config, README, package metadata, scripts, CI files, or prior result files.
- Gate mechanisms: Claude Code hooks, Git hooks, wrapper scripts, workflow state files, worktree rules, branch naming rules.

State assumptions only after this inspection. If the repo has stricter rules than this skill, follow the repo.

## 1. Start Gate

If the project defines an iteration gate, trigger it through the project's documented entrypoint instead of bypassing it.

This repository also includes an optional Claude Code hook template at `scripts/claude-code-gate.sh`. Use it only when the project wants code-level enforcement instead of prompt-only discipline. Copy it into the target project and tune it through environment variables rather than editing project-specific paths into the script.

Common trigger phrases:

- `开始循环优化：<topic>`
- `按反馈优化：<topic>`
- `/iterative-improve <topic>`

If a gate is active:

- Treat gate denial as a real process error, not an inconvenience.
- Read the denial message and satisfy the missing requirement.
- Do not delete state files unless the user asks to exit/cancel the loop or the gate provides a documented reset command.

If the project has no gate:

- Simulate the gate behavior manually: no mutating work until the plan exists and the user/project rules permit execution.
- Keep the same artifact discipline: one plan and one result per round.

### Exiting A Gate

Use only documented exit paths. Typical examples:

- Ask the agent: `退出 gate`, `关闭循环优化`, `取消循环优化`, or equivalent.
- Run a project-provided reset command such as `bash .claude/hooks/optimization-gate.sh --reset`.
- As a last resort, use the documented state-file removal command, if the project explicitly supports it.

After exiting, state that the loop is canceled and stop iterative execution.

## 2. Plan Phase

Use real Plan Mode when available. If Plan Mode tools are unavailable, enforce a read-only planning phase yourself.

Planning rules:

- Read relevant code/config/results before designing changes.
- Do not edit code, run migrations, run long experiments, or commit during planning.
- Plan only the next round. Do not pre-plan all future rounds.
- Choose one primary bottleneck for the round.
- Prefer structural improvements over blind parameter tuning unless the user asked for tuning.

Each plan file must include:

- Goal and success criteria.
- Current state and previous-round findings, if any.
- Scope and explicit non-goals.
- Implementation approach with affected subsystems.
- Verification commands and acceptance criteria.
- Risk/revert plan.
- Execution logistics required by the project: worktree, branch, commit, merge, cleanup, or deployment steps.

If a project gate validates `ExitPlanMode`, make the plan satisfy that gate exactly.

## 3. Worktree And Branch Isolation

Before mutating files, follow the project's isolation policy.

Default generic policy:

- Use a dedicated worktree/branch for multi-round loops or risky changes.
- Use one worktree for the whole loop, not one worktree per round.
- Do not hard-code the base branch; discover it with Git.
- Do not merge from inside the loop worktree unless project rules explicitly allow it.
- If the project has data directories or large local artifacts, follow its symlink/copy safety rules exactly.

For tiny documentation-only or single-file fixes, a worktree may be unnecessary if project rules allow direct edits.

## 4. Execute One Round

For each round:

1. Confirm the plan for this round exists.
2. Implement only the planned change.
3. Remove only unused code created by this round.
4. Run the planned verification.
5. Generate or inspect real output when output quality matters.
6. Commit if the project workflow requires per-round commits.

Do not continue to the next round just because implementation finished. Verification and review are part of the round.

## 5. Review

Run the strongest available review method:

- Project-specific review skill/tool when present.
- Existing test/CI/report validation.
- A focused self-review of the diff and output.
- External/web research only when the topic benefits from current information or the project requires it.

Review for:

- Correctness against the plan.
- Regression risk.
- Data/schema/interface compatibility.
- Safety constraints and forbidden side effects.
- Output quality or metric quality, as appropriate for the module.

Do not invent a universal metric. Use the project's domain metrics when they exist; otherwise use observable quality criteria.

## 6. Result File

Each round writes exactly one result file in the discovered results directory.

Include:

- What changed.
- Verification commands and outcomes.
- Output/metric comparison when applicable.
- Review findings by severity.
- Keep/discard decision for the round.
- The single biggest bottleneck for the next round.

Do not report final success from memory; read the actual files/logs/results.

## 7. Continue Or Stop

Continue when:

- Max rounds has not been reached.
- Verification passed or produced actionable findings.
- The next bottleneck is clear and in scope.

Stop when:

- Max rounds reached.
- Two consecutive rounds produce no substantive findings.
- Further work needs user judgment, credentials, new data, budget, or external access.
- The latest result shows the approach is not worth continuing.
- The user exits/cancels the gate.

When stopping, summarize the loop with links/paths to plans, results, commits, and remaining risks.

## 8. Safety Defaults

- Never bypass hooks or gates silently.
- Never use destructive Git commands unless the user explicitly asks and project rules allow them.
- Never overwrite unrelated user changes.
- Never treat a failed gate as permission to manually mutate state.
- Keep changes surgical: every changed line must trace to the current round's plan.
- Prefer deterministic scripts/hooks for fragile enforcement; use prompts only for judgment.
