---
name: iterative-improve
description: Run a gate-enforced iterative improvement loop for a project, module, strategy, report pipeline, or product workflow. Use when the user gives an explicit command such as "/iterative-improve", "循环优化", or "iterative improvement", or asks an agent to repeatedly plan, implement, verify, review, and continue across rounds while obeying a mandatory gate, Plan Mode, worktrees or branch isolation, commits, and result artifacts.
---

# Iterative Improve

Run a controlled loop: **discover rules → activate gate → analyze prior result → plan → implement → verify → review → write result → merge/cleanup → choose next round**.

This skill is generic. Do not hard-code one repository, metric, tool, branch name, directory layout, or Claude/Codex feature. Discover project rules from local files and enforce the required gate before any mutating iterative-improvement work.

## 0. Discover The Local Contract

Before the first round, inspect local sources of truth:

- Agent instructions: `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, docs under `docs/agents/` when present.
- Existing iteration artifacts: `plans/`, `results/`, `reports/`, or module/repository-specific equivalents.
- Verification commands from config, README, package metadata, scripts, CI files, or prior result files.
- Gate mechanisms: Claude Code hooks, Git hooks, wrapper scripts, workflow state files, worktree rules, branch naming rules.

State assumptions only after this inspection. If the repo has stricter rules than this skill, follow the repo.

Default artifact directories are `plans/` and `results/` at the project root. If they are missing and the gate/installer did not already create them, create only those directories before writing the gate plan. Use `plans/*.md` for plan files and put the planned future result path under `results/*.md` unless project configuration explicitly overrides the gate directories.

## 1. Start Mandatory Gate

Using this skill requires a gate. Treat the gate as part of the skill contract, not an optional add-on.

Before planning or mutating files:

- If the project already defines an iteration gate, trigger it through the project's documented entrypoint.
- If the project does not define a gate and Claude Code hooks are available, run this repository's `install.sh` from the target project root to install the required project hook.
- If no hook or equivalent enforcement mechanism is available, stop before implementation and tell the user that `/iterative-improve` cannot safely run without a gate.

Do not replace the gate with prompt-only discipline. Prompt discipline can explain what to do, but it is not a gate.

Default trigger commands:

- `/iterative-improve`
- `/iterative-improve <topic>`
- `循环优化`
- `循环优化：<topic>`
- `iterative improvement`
- `iterative improvement: <topic>`

The default gate is intentionally strict and line-based. Repository URLs, installation prompts, quoted docs, and ordinary mentions of `iterative-improve` do not activate it.

When the gate is active:

- Treat gate denial as a real process error, not an inconvenience.
- Read the denial message and satisfy the missing requirement.
- Do not delete state files unless the user asks to exit/cancel the loop or the gate provides a documented reset command.

If the gate cannot be activated, do not proceed with the loop. You may inspect files and propose installation steps, but do not edit project code, run experiments, commit, merge, or clean up as part of an iterative-improvement round.

### Optional Auto-Approve Hooks

`PermissionRequest` auto-approve hooks for `ExitPlanMode` are optional companion tools, not part of this skill's required gate. Do not install, vendor, or recreate third-party auto-approve hooks as part of `/iterative-improve`.

This skill's enforcement must come from the project gate, normally `UserPromptSubmit` and `PreToolUse`. Gate state should be session-scoped so one active loop does not block unrelated sessions in the same project. If a separate auto-approve hook is already installed, treat UI messages such as `Allowed by PermissionRequest hook` as approval of Claude Code's dialog only; the iterative-improve plan is valid only if the gate did not deny `ExitPlanMode`.

### Exiting A Gate

Use only documented exit paths. Typical examples:

- Ask the agent: `退出 gate`, `关闭循环优化`, `取消循环优化`, or equivalent.
- Run a project-provided reset command such as `bash .claude/hooks/optimization-gate.sh --reset`.
- As a last resort, use the documented state-file removal command, if the project explicitly supports it.

After exiting, state that the loop is canceled and stop iterative execution. Restarting requires activating the gate again.

## 2. Plan Phase

Use real Plan Mode when available. If Plan Mode tools are unavailable, use the gate's read-only planning state; if no gate can enforce that state, stop before implementation.

Planning rules:

- Read relevant code/config/results before designing changes.
- For round 2 and later, read the previous round's result file before writing the next plan.
- The next plan must explicitly analyze the previous result: what passed, what failed, what was kept/discarded, and why the next bottleneck follows from that evidence.
- Do not edit code, run migrations, run long experiments, or commit during planning.
- Plan only the next round. Do not pre-plan all future rounds.
- Choose one primary bottleneck for the round.
- Prefer structural improvements over blind parameter tuning unless the user asked for tuning.
- Write the actual gate plan as a Markdown file under `plans/` by default. Do not rely on an internal UI task plan or checklist as the gate plan.

Each plan file must include:

- Goal and success criteria.
- Current state and previous-round findings. For round 1, state that there is no previous result. For round 2 and later, include a `Previous Result Analysis` section with the previous result file path.
- Scope and explicit non-goals.
- Implementation approach with affected subsystems.
- Verification commands and acceptance criteria.
- Risk/revert plan.
- A concrete result file path under the project's result directory.
- Execution logistics required by the project: worktree, branch, commit, merge, cleanup, or deployment steps.

The gate must validate the plan before implementation. Make the plan satisfy the active gate exactly. At ExitPlanMode, the plan file must exist in a configured plan directory; the planned result file path must be named under a configured result directory, but the result file does not need to exist yet.

## 3. Worktree And Branch Isolation

Before mutating files, follow the project's isolation policy.

Default generic policy:

- Use a dedicated worktree/branch for multi-round loops or risky changes.
- Use one worktree for the whole loop, not one worktree per round.
- Do not hard-code the base branch; discover it with Git.
- Prefer generic `improve/*` branches and `<repo>-improve-*` worktrees unless project rules specify another naming scheme. Existing `opt/*` naming is acceptable when the project uses it.
- Do not merge from inside the loop worktree unless project rules explicitly allow it.
- If the project has data directories or large local artifacts, follow its symlink/copy safety rules exactly.

For tiny documentation-only or single-file fixes, a worktree may be unnecessary only if the active gate and project rules explicitly allow direct edits.

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

Each round writes exactly one result file in the discovered results directory. Use `results/` by default unless project configuration explicitly overrides it.

Include:

- What changed.
- Verification commands and outcomes.
- Output/metric comparison when applicable.
- Review findings by severity.
- Keep/discard decision for the round.
- The single biggest bottleneck for the next round.
- A `Next Round Handoff` section that names the evidence-backed next bottleneck, recommends the next plan focus, and lists any stop conditions.

Do not report final success from memory; read the actual files/logs/results.

## 7. Continue Or Stop

Continue when:

- Max rounds has not been reached.
- Verification passed or produced actionable findings.
- The next bottleneck is clear and in scope.
- The next plan can cite and analyze the latest result file.

Stop when:

- Max rounds reached.
- Two consecutive rounds produce no substantive findings.
- Further work needs user judgment, credentials, new data, budget, or external access.
- The latest result shows the approach is not worth continuing.
- The previous result file is missing, unreadable, or too ambiguous to justify the next round.
- The user exits/cancels the gate.

When stopping, summarize the loop with links/paths to plans, results, commits, and remaining risks.

## 8. Safety Defaults

- Never bypass hooks or gates silently.
- Never run this skill in implementation mode without an active gate.
- Never use destructive Git commands unless the user explicitly asks and project rules allow them.
- Never overwrite unrelated user changes.
- Never treat a failed gate as permission to manually mutate state.
- Keep changes surgical: every changed line must trace to the current round's plan.
- Prefer deterministic scripts/hooks for fragile enforcement; use prompts only for judgment.
