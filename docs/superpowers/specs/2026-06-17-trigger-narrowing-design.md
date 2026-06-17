# Trigger Narrowing Design

## Goal

Prevent the iterative-improve gate from activating when a prompt only mentions the repository, install instructions, or documentation examples. The gate should activate only for explicit command-style requests.

## Scope

- Narrow the default trigger behavior in `scripts/claude-code-gate.sh`.
- Keep the rest of the gate lifecycle unchanged.
- Update public docs so the trigger contract is explicit.

## Trigger Contract

The default gate activation should recognize only these line-oriented commands:

- `/iterative-improve`
- `/iterative-improve <topic>`
- `循环优化`
- `循环优化: <topic>`
- `循环优化：<topic>`
- `iterative improvement`
- `iterative improvement: <topic>`

The trigger should be evaluated line by line. A prompt activates the gate only when at least one full line matches one of the command forms above after trimming surrounding whitespace.

## Non-Goals

- No new configuration surface beyond the existing `ITERATIVE_IMPROVE_TRIGGER_REGEX`.
- No change to reset behavior.
- No change to plan validation, worktree enforcement, or cleanup rules.

## Implementation Approach

Add a small helper in the gate script that:

1. Splits the prompt into lines.
2. Trims each line.
3. Matches each trimmed line against a strict trigger regex.

The default trigger regex should cover only the command forms in the contract above. Repository URLs, quoted README examples, or explanatory prose should not match.

## Verification

- Add a regression test script that exercises matching and non-matching prompts.
- Verify the new tests fail before the gate change.
- Re-run the tests after the change and confirm they pass.
- Run `bash -n` on the modified shell script.
