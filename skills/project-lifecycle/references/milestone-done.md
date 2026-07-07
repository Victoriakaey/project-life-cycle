# Milestone-Done Gate

A milestone is "done" only when all of the following are true. Anything else is "code-complete, not done."

## Hard gates

- [ ] All planned tasks closed (each with a journal entry).
- [ ] All Important review findings either fixed or written to backlog with Trigger + Exit criteria.
- [ ] **S1-tier findings:** zero open (S2 / S3 OK with follow-up issues — see `findings-tier.md`).
- [ ] Automated test suite green (unit + integration + relevant E2E).
- [ ] Coverage at or above the project floor.
- [ ] Linter / formatter / type checker clean across changed files.
- [ ] Generated artifacts (schema, types, migrations) regenerated and committed.
- [ ] Pre-commit run on all changed files locally before final push (see `ci-cd-gates.md` Layer 1).
- [ ] **CI pipeline complete** — format / lint / type / tests / coverage floor / schema drift / handoff-doc-presence all green (see `ci-cd-gates.md` Layer 2).
- [ ] **Branch protection enforced** on `main` (no direct push, no force push, CI required — see `ci-cd-gates.md` Layer 3).
- [ ] **Phase handoff doc exists** at `docs/handoff/YYYY-MM-DD-phase-X.Y-handoff.md` and follows the 8-section structure in `references/handoff-template.md`.
- [ ] **PR description opens with a plain-language TL;DR** (4-6 sentences, zero jargon, as 4 bullet points: Problem / What we did / Why we did it / Result + honest boundary), then copies handoff §1 + §4 summary + §7 (template in handoff appendix).
- [ ] PR opened, CI green, merged to main.
- [ ] If the milestone introduced user-visible surface: **dual-track smoke** done — Track A manual checklist run end-to-end (real browser / device) + Track B Playwright (or equivalent) green. See `smoke-tracks.md`.

## Documentation gates

- [ ] `RESUME.md` updated with the milestone's progress section + commit SHAs.
- [ ] Status-file ring rotated (if the read-first status doc carries closing paragraphs): active section holds active + ≤2 closed entries; oldest closed paragraph moved **verbatim** to the dedicated archive file in the same edit, pointer line present (per `references/roadmap.md` §"Close protocol — the status-file ring"; deliberately not machine-gated).
- [ ] `iteration-journal.md` has an entry for every task.
- [ ] Backlog files updated for any deferred items.
- [ ] Project-wide Q&A log appended with milestone completion record.
- [ ] ADRs created for any architectural decisions made during the milestone (per `adr.md` 3-criteria gate; skip if no decision qualified).
- [ ] CONTEXT.md / CONTEXT-MAP.md reflects every new domain term resolved during the milestone (per `context-md.md`). No silent drift between code names ↔ glossary.
- [ ] If new dependencies were adopted: README installation / setup instructions updated.
- [ ] Phase handoff doc references the spec / plan / smoke checklist (cross-link sanity).
- [ ] All locked design decisions in the spec carry an evidence-strength tag (🟢 / 🟡 / 🔴) — 🔴 entries explicitly flagged for higher-priority review.

## Validation gates

- [ ] No journal entry has an empty "Plan deviations" body without explicit "none" (use the schema in `journal-schema.md`).
- [ ] No "Important" or "Critical" review findings are open without resolution.
- [ ] No Critical finding was downgraded to Important without explicit justification in the journal.
- [ ] The smoke checklist (if applicable) covers the milestone's headline user flows, not just unit-test surfaces.

## When to roll back

If a milestone fails the gate, the milestone is not done. Don't ship. Options:

1. Add a closing task that addresses the failing gate.
2. Defer the gap to backlog (only for non-blocking items).
3. Roll back the merge if the gap is a regression.

The gate is the line. Crossing it without fixing is a process violation.
