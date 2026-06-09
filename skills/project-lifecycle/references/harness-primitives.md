# Native Claude Code Harness Primitives

This skill predates a wave of native Claude Code primitives that now realize, as
first-class platform features, several harness concepts the skill previously could
only describe in prose ("dispatch parallel reviewers", "the un-bypassable layer",
"auto-load RESUME on resume"). This doc maps each **verified** primitive to the
skill node it strengthens, and how to use it.

> **Verification provenance.** Every primitive below was checked against the
> official `code.claude.com/docs` changelog + hooks reference on **2026-06-08**.
> Two primitives a research pass had suggested were checked and **NOT found** —
> `/batch` and skill-frontmatter `invocationMode` — and are deliberately omitted.
> Do not cite them. Re-verify versions before relying on exact behavior; the
> platform moves fast.

The skill's framing still holds: **the harness IS the contract.** These primitives
just move more of the contract from "model remembers the prose rule" to
"platform enforces it deterministically" — which is exactly the direction the
"Definition of Done" + close-gate already point.

---

## 1. Skill-frontmatter hooks — the self-enforcing layer

**What it is.** Hooks declared directly in this skill's YAML frontmatter, scoped to
the skill's lifecycle: they fire **only while the skill is active** (invoked). All
hook events are supported (`PreToolUse`, `Stop`, `SubagentStop`, …). `Stop` /
`SubagentStop` can return `hookSpecificOutput.additionalContext` to inject text
back into the model's context.

**Verified firing (2026-06-08).** A throwaway test skill confirms in a
live session that a frontmatter `PreToolUse:Bash` hook fires on a real tool call
AND its `additionalContext` is injected into the transcript. Registration happened
**mid-session** on skill invocation (no restart needed to register; but see the
caveat below).

**Node it strengthens.** "Definition of Done" + `references/close-gate.md`. The
close-gate's weakest layer was "model-run discipline". Frontmatter hooks add a
platform-enforced nudge that ships *with the skill* — no per-project `settings.json`
wiring required.

**How this skill uses it** (see SKILL.md frontmatter `hooks:` block + scripts in
`skills/project-lifecycle/hooks/`):
- `PreToolUse:Bash` → `hooks/guard.sh`: blocks `--no-verify` and direct
  `git push` to `main` while the skill is active (exit 2 = block). Belt-and-braces
  with the git pre-push hook; this one travels with the skill.
- `Stop` + `SubagentStop` → `hooks/close-gate-nudge.sh`: **conditional** — emits an
  `additionalContext` reminder ONLY when on a `feat/phase-*` branch with uncommitted
  changes or stale test-evidence. Silent otherwise (no per-turn noise).

**Caveats / layer rules.**
- **`SessionStart` does NOT belong in skill frontmatter** — at session start the
  skill is not yet active, so the hook would never fire. Session-start behavior
  (e.g. RESUME injection, §2) lives in project `settings.json`.
- Keep hook *logic* in a shipped script (`hooks/*.sh`), not inline in the
  frontmatter command string — the script is unit-testable standalone (pipe it a
  fake event JSON, assert stdout shape + exit code); the frontmatter is not.
- A broken frontmatter `hooks:` block can make the skill fail to load. Always run
  the YAML-parse + script-standalone checks (see `hooks/test-hooks.sh`) before sync.
- Live skill edits do not reload mid-session — new/changed hooks take effect next
  session.

---

## 2. `SessionStart` hook matchers (`resume` / `clear` / `compact` / `startup`)

**What it is.** A `SessionStart` hook can match on *how* the session began. The
`resume` matcher fires on `--resume` / `--continue` / `/resume`; `clear` fires on
`/clear`; `compact` on compaction.

**Node it strengthens.** The skill's core context-boundary contract: mandatory
`/clear` between phases + `RESUME.md` as the canonical resume artifact. Today the
model is *told* to read RESUME on resume; a `SessionStart:resume` hook makes that
deterministic — inject the current phase + RESUME head automatically.

**How to wire it.** This is a **project** concern, not a skill-frontmatter one
(skill inactive at session start). Ship it as a recommended block in the project's
`.claude/settings.json`, installed by `/init-harness`:

```json
{ "hooks": { "SessionStart": [
  { "matcher": "resume",
    "hooks": [{ "type": "command",
      "command": ".claude/hooks/inject-resume.sh" }] } ] } }
```

where `inject-resume.sh` emits `hookSpecificOutput.additionalContext` with the head
of `RESUME.md` + the current `feat/phase-*` branch. Do NOT install this into the
user's global `~/.claude/settings.json` — it is per-project, and the global file
holds the user's own unrelated hooks.

---

## 3. Dynamic Workflows / `ultracode` — deterministic cadence orchestration

**What it is.** Script-driven orchestration (`pipeline()` / `parallel()` /
`agent({schema})`) that fans work across many subagents with code-controlled flow
and schema-forced structured output. Triggered by the `ultracode` keyword (renamed
from `workflow`, v2.1.160) or "ask Claude to create a workflow".

**Node it strengthens.** The per-task cadence (`references/cadence.md`) and `/ship`
are currently prose step-lists executed by model self-discipline — exactly the
"model feels done, skips wrap-up" failure the skill fights. A Workflow script makes
the fan-out (implementer → acceptance verifier → validator → code-quality → fixup →
journal) **deterministic control flow**, and `schema` forces each step to return a
validated object instead of free text.

**Status / how to adopt.**
- **Documented option now.** When a cadence task or `/ship` slice is large and the
  orchestration shape is known, encode it as a Workflow script: `pipeline()` over
  the cadence steps, `parallel()` for the independent reviewers (§4), `schema` on
  each `agent()` for the Builder Summary / Validator Report / Acceptance Report.
- **Full `/ship` → Workflow conversion is its own milestone**, not a doc edit — it
  re-implements `commands/ship.md` as a script and must go through this skill's own
  brainstorm → spec → TDD discipline; do not silently rewrite.

---

## 4. `run_in_background` + `Monitor` — parallel independent reviewers

**What it is.** `Agent(run_in_background: true)` detaches a subagent; `Monitor`
waits on completion. Parallel sibling tool calls no longer cancel each other on one
failure (v2.1.154).

**Node it strengthens.** Cadence step 2 (Validator) and step 3 (Code-quality
review) are **independent read-only passes over the same diff** — no data
dependency. Today they run sequentially. Dispatch them in parallel (single message,
two `Agent` calls, or background + `Monitor`) to cut wall-clock. Same for the
acceptance verifier when it only reads `src/`.

**Guard.** Keep the ordering dependency that IS real: implementer (step 1) →
*then* the review trio. Only the trio parallelizes. The validator's lie-detection
pass still consumes the Builder Summary, so it starts after the builder returns.

---

## 5. Worktree isolation (`isolation: "worktree"`, `EnterWorktree`)

**What it is.** An agent can run in its own git worktree so parallel agents mutating
files don't collide. (Expensive — only when agents actually write in parallel.)

**Node it strengthens.** `references/builder-split.md` (BE + FE builders) and
`references/issue-breakdown.md` (tracer-bullet issues). The split currently relies
on **folder-scoped tools** as a soft boundary; worktree isolation is the *physical*
version when BE and FE genuinely run concurrently. Use it only when parallelizing
builders — the BE→FE sequence (BE emits contract, FE consumes) usually does NOT
need it, and worktree setup has real per-agent cost.

---

## 6. `AskUserQuestion` — structured opt-in checkpoints

**What it is.** A native structured multiple-choice prompt (labels + descriptions +
a recommended-first option), instead of free-text "I'll ask in prose".

**Node it strengthens.** The skill has many "ask the user once" opt-ins currently
phrased as prose questions:
- brainstorm Mode A vs B (`references/brainstorm-research-protocol.md`)
- `html-policy` companion opt-in (steps 1 / 4 / 9, `references/output-format.md`)
- `smoke-mode` self vs guided (step 8)
- intent-gate confirm-intent (`references/intent-gate.md`, when a question is
  genuinely needed)

Use `AskUserQuestion` for these: it makes the choice + recommendation legible and
one-tap, and the answer is machine-readable. Keep prose for genuinely open-ended
elicitation (brainstorm design questions) — `AskUserQuestion` is for bounded forks.

---

## 7. Plan mode (`EnterPlanMode` / `ExitPlanMode`) — checkpoint gates

**What it is.** A native read-only planning mode; `ExitPlanMode` surfaces the plan
for explicit user approval before any edit.

**Node it strengthens.** The skill's human checkpoints: `/ship`'s 3 checkpoints
(story / spec / PR) and the per-phase Plan step (4). Wrapping the plan/spec
sign-off in native plan mode turns "the model promises it paused for approval" into
a platform-enforced gate that cannot edit until the user exits plan mode.

---

## 8. Smaller wins — `/goal`, `/context`, `/branch`

- **`/goal`** (v2.1.139): set a completion condition; Claude keeps working across
  turns until met. Useful for a long-running phase that spans `/clear` boundaries —
  encode the phase's exit criteria (close-gate green) as the goal. Optional.
- **`/context`** (and `/context all`): visualize what consumes the window
  (CLAUDE.md / skills / subagents / MCP / history). Add to
  `references/cost-aware-behaviors.md` as the tool to decide `/clear` vs `/compact`
  at a phase boundary, instead of guessing.
- **`/branch`**: fork the session mid-conversation to try an alternate approach
  without losing the original. Useful during brainstorm when exploring two designs,
  or before a risky refactor. Optional.

---

## Adoption summary

| Primitive | Skill node | Status |
|---|---|---|
| Frontmatter hooks | close-gate / Definition of Done | **wired** (SKILL.md `hooks:` + `hooks/`) |
| `SessionStart:resume` | RESUME contract | recommended project-settings block (init-harness) |
| Workflows / `ultracode` | cadence + `/ship` | documented option; a full `/ship` port is a separate piece of work |
| `run_in_background` / `Monitor` | cadence steps 2+3 | documented (parallel reviewers) |
| Worktree isolation | builder-split / issue-breakdown | documented (only when builders run concurrently) |
| `AskUserQuestion` | opt-in checkpoints | documented (replaces freeform forks) |
| Plan mode | `/ship` + Plan-step checkpoints | documented |
| `/goal` `/context` `/branch` | cost-aware / phase span | documented, optional |
