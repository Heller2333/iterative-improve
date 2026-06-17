# Trigger Narrowing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restrict iterative-improve gate activation to explicit command-style prompts so install and documentation prompts do not enter gate mode.

**Architecture:** Keep the existing gate flow intact and replace only the trigger-detection entrypoint with line-based matching. Add a small shell regression test that proves command lines activate the gate and incidental mentions do not.

**Tech Stack:** Bash, jq

---

### Task 1: Add regression coverage for trigger detection

**Files:**
- Create: `tests/trigger-detection.sh`
- Modify: `scripts/claude-code-gate.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/trigger-detection.sh` with cases that expect activation for explicit commands and no activation for repository mentions:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/scripts/claude-code-gate.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

make_project() {
  local dir="$TMP_ROOT/project"
  mkdir -p "$dir/.claude/hooks"
  cp "$HOOK" "$dir/.claude/hooks/iterative-improve-gate.sh"
  chmod +x "$dir/.claude/hooks/iterative-improve-gate.sh"
  printf '%s\n' "$dir"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/trigger-detection.sh`
Expected: FAIL on a non-command prompt that still activates the gate under the old substring-based matching.

- [ ] **Step 3: Write minimal implementation**

Implement a helper in `scripts/claude-code-gate.sh` that scans prompt lines and matches only strict command forms.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/trigger-detection.sh`
Expected: PASS with all command and non-command cases succeeding.

- [ ] **Step 5: Commit**

```bash
git add tests/trigger-detection.sh scripts/claude-code-gate.sh
git commit -m "fix: narrow iterative-improve trigger activation"
```

### Task 2: Update docs for the new trigger contract

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Document the allowed trigger forms**

Add the explicit command list and line-based matching rule to the public docs and technical reference.

- [ ] **Step 2: Document what no longer triggers the gate**

Call out that repository URLs, installation prompts, and ordinary mentions of `iterative-improve` do not activate the gate.

- [ ] **Step 3: Verify docs and shell syntax**

Run: `bash tests/trigger-detection.sh && bash -n scripts/claude-code-gate.sh install.sh`
Expected: PASS with no shell syntax errors.

- [ ] **Step 4: Commit**

```bash
git add README.md README.zh-CN.md AGENTS.md
git commit -m "docs: clarify strict iterative-improve trigger commands"
```
