# Per-Task Cadence

Five steps per task. Each is a separate, observable artifact (subagent dispatch, commit, or both).

## Step 1: Dispatch implementer subagent

Controller (the orchestrating agent) prepares the implementer prompt:

- **Full task text** from the plan (don't make the subagent read the plan file).
- **Scene-setting context** — what previous tasks built that this one depends on.
- **Adapt-to-existing-patterns guidance** — when the plan was written before the codebase matured, the live code may have established conventions (typed wrappers, helper objects, naming) that the plan snippet doesn't reflect. The controller MUST tell the implementer to use the live conventions, not blindly copy the plan.
- **First-of-its-kind detection** — if this task is the first to introduce a new tooling category (test runner, language toolchain, container runtime, contract format, etc.), the controller MUST either insert a bootstrap step or list the missing infra in the prompt.
- **Status reporting format** — DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT.

The implementer commits the work as a `feat(...)` (or `test(...)` / `fix(...)` if appropriate) commit and reports back.

## Step 2: Spec compliance review

Independent subagent. Lens: **did the implementer build exactly what the plan asked for, no more, no less?**

- Verify each spec bullet is addressed in code.
- Flag missing requirements (under-build).
- Flag added features beyond spec (over-build).
- Flag misinterpretations (built the wrong thing).

Output: ✅ Spec compliant OR ❌ Issues found (with file:line references).

If issues found, the same implementer fixes them in a `fix(...)` commit. Re-review until clean.

## Step 3: Code quality review

Independent subagent (dispatch via `superpowers:requesting-code-review`, or an equivalent reviewer agent). Lens: **is the implementation well-built?**

Standard concerns: design, naming, error handling, security, a11y (UI), performance, test quality.

**Plus a third category — forward-looking findings.** A finding that says "this works for the spec, but a downstream task will be hurt by it" (e.g., generated artifact uses an unstable name; consumer task hasn't been written yet but will need a stable name). Reviewer should explicitly call these out.

Output: Strengths / Critical / Important / Minor / Forward-looking / Overall Assessment.

If issues found, dispatch a fix subagent (typically the same implementer pattern). Re-review until approved.

## Step 4: Fixup commit

If review found issues, the fixup is a **separate commit** on top of the original. Never amend the original `feat(...)`; never squash the review history away.

Resulting git log per task:

```
feat(...): original implementation
fix(...): review follow-ups (if any)
fix(...): smaller follow-up (if any)
docs(...): journal entry
```

This makes review feedback traceable in `git log` and preserves the original work as a reviewable artifact.

## Step 5: Journal entry

Separate `docs:` commit. Follows the 6-section schema in `journal-schema.md`. Covers the **whole task** (all of its commits), not each commit individually.

## Cadence Compression (Mechanical Tasks)

For purely mechanical tasks — single-file regen, schema bump, lockfile update, mechanical refactor that preserves behavior — the default 5-step cadence is overhead.

**Compress to 4 steps** (merge spec + code review into one pass) when **all three** conditions hold:

1. The diff is small relative to project norms.
2. No new logic or control flow is introduced.
3. No security / compliance / auth surface is touched.

If even one condition fails, run the full 5 steps.

The combined reviewer is dispatched once and asked for both spec compliance and quality assessment in a single output.

## Controller Anti-Patterns

- Letting the implementer read the plan file directly — wastes context, lets implementer skip the controller-added "adapt" guidance.
- Dispatching multiple implementers in parallel against the same files — they'll conflict.
- Merging review feedback into the implementer's prompt instead of running a separate fix dispatch — loses the review trail.
- Skipping spec compliance review because "the code looks right" — different bug class.
- Skipping code quality review because spec compliance passed — different bug class.
- Marking task complete with open Important findings unaddressed — apply defer-vs-fix triage instead.
