# ROADMAP — the project's whole-plan map

The single document that answers "what is the entire plan, and where am I in it?" at a glance. Its job is to survive long projects: by milestone 9 the human (and the AI) has forgotten the shape of the whole thing — ROADMAP is the cure.

`RESUME.md` answers *"what do I do next?"* (narrow, current-phase). ROADMAP answers *"what is the whole journey?"* (wide, all milestones). They are complementary; do not merge them.

## When it is created

- **At project kickoff**, by `/init-harness` (seeded stub) OR at the end of the first milestone's brainstorm once the milestone breakdown is known.
- If a project predates this convention, create it the next time the milestone list is discussed.

## When it is updated

ROADMAP is **append-and-amend**, updated at three moments:

1. **Milestone boundary** (in the same commit as the handoff + RESUME update): flip the just-finished milestone's status to ✅, set the next one to ▶ (current).
2. **Scope change**: when milestones are added, split, merged, reordered, or dropped — amend the table and add a dated one-line note under "Plan changes" explaining why (this is the drift signal; never silently rewrite history).
3. **Milestone-done gate**: the gate checks that ROADMAP reflects reality before closing.

## Canonical location

`docs/ROADMAP.md` (MD is the source of truth). An optional `docs/ROADMAP.html` companion may be generated under the normal `html-policy` opt-in (it is one of the HTML-companion-eligible artifacts — same ask-once rule as the spec/design and milestone-summary nodes).

## Required structure

```markdown
# Roadmap — <project>

## Index
- [The one-sentence goal](#...)
- [The shape of the work](#...)
- [Milestones](#...)
- [How a milestone runs](#...)
- [What "done" looks like](#...)
- [Plan changes](#...)

## The one-sentence goal
<what this project is, in one sentence — the thing you'd forget by milestone 9>

## The shape of the work
<2-4 "blocks" that group the milestones into phases of intent, in order.
e.g. "build the substrate → plug tools in → synthesize". State the load-bearing
invariant the whole plan rests on, if there is one.>

## Milestones
| # | Milestone | What gets built | Depends on | Status |
|---|---|---|---|---|
| M1 | ... | ... | — | ✅ done |
| M2 | ... | ... | M1 | ▶ current |
| M3 | ... | ... | M2 | ☐ planned |
<status legend: ✅ done · ▶ current · ☐ planned · ⏸ paused · ✗ dropped>

## How a milestone runs (the repeating loop)
<the per-phase cadence, so a reader knows the rhythm — usually a fixed block,
copy the project-lifecycle loop: brainstorm → user-story → spec → plan →
build → smoke → handoff → PR → /clear>

## What "done" looks like
<the end-state acceptance: what exists + what's true when the whole project ships>

## Plan changes
<dated, append-only log of scope changes. "2026-06-10 — split M5 into M5a/M5b
because the deep-dive was too big for one phase." Drift is signal; record it.>
```

## Status legend (use exactly these)

| Glyph | Meaning |
|---|---|
| ✅ | done (merged) |
| ▶ | current (in progress) |
| ☐ | planned (not started) |
| ⏸ | paused (blocked / deferred, with reason in Plan changes) |
| ✗ | dropped (with reason in Plan changes) |

## Relationship to other docs

| Doc | Scope | Question it answers |
|---|---|---|
| **ROADMAP.md** | whole project | "What is the entire plan + where am I?" |
| **RESUME.md** | current phase | "What is the very next action?" |
| **decisions.md** (if used) | cross-cutting | "What did we lock and why?" |
| **iteration-journal.md** | per-task history | "What happened, in order?" |

ROADMAP links into RESUME ("current milestone detail → see RESUME") and RESUME links back up ("full plan → see ROADMAP").

## Anti-patterns

- **Merging ROADMAP into RESUME** — RESUME churns every phase and gets `/clear`-truncated; the whole-plan map must be stable and separate.
- **Letting ROADMAP go stale** — a roadmap that still says "M2 current" at milestone 9 is worse than none; the milestone-done gate exists to catch this. Update it in the same commit as the handoff.
- **Silently rewriting the milestone list on scope change** — amend the table AND log the change under "Plan changes" with a date + reason. The drift is the most valuable signal.
- **Over-detailing future milestones** — far-out milestones get one line; detail accrues as they approach. ROADMAP is a map, not a spec.
- **Per-task entries** — that's the journal's job. ROADMAP is milestone-granularity only.
