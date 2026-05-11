# Phase Handoff Doc

Every phase ends with a **single delivery document** that lets a reviewer (typically the product owner) understand and verify the work in 5 minutes without reading code or git log.

## When to write

After all phase tasks are done + smoke artifacts ready, before opening the PR. Drop the file at:

```
docs/handoff/YYYY-MM-DD-phase-X.Y-handoff.md
```

(Path convention: `YYYY-MM-DD` = handoff date, `X.Y` = phase number, all lowercase.)

## 8 mandatory sections

| # | Section | Content | Audience |
|---|---|---|---|
| 1 | **What shipped** | 3–8 short bullets in **"I can now..."** voice, daily language, no jargon | Product owner |
| 2 | **How to use** | Real usage scenarios — NOT QA steps. "If you want to do X, click Y" | Product owner |
| 3 | **What changed** | New files + modified files + migrations + API surface changes + commit index | Reviewer / future-you |
| 4 | **Manual smoke** | Link to the full Track A checklist + 5-line summary of headline steps | Product owner (runs it) |
| 5 | **Automated smoke** | `make phase-checks PHASE=X.Y` output (or equivalent) + last result + branch sha | Reviewer (already ran) |
| 6 | **Code-level tests** | pytest/vitest counts + new test file list | Reviewer (already ran) |
| 7 | **Known limitations / Findings** | Sorted by tier (S1/S2/S3 — see `findings-tier.md`) | Reviewer (decides merge) |
| 8 | **Next-step recommendations** | Merge gate, follow-up issues to file, what later phase should cover | Product owner |

Plus an **appendix** with a copy-paste-ready PR description body.

## Tone rules

- **§1 + §2 are for the product owner.** Use daily language. Never write internal type names ("FooBarJoinModel") or DB column references — translate into the user-facing capability ("each item in the form can now be tagged with a category").
- **§3 + §5 + §6 are for reviewers.** Technical detail welcome.
- **§7 is for both.** Plain-language description of each finding + technical workaround.

If you write §1 with jargon, you failed. Rewrite.

## Findings format

Each finding gets a stable ID (`F1`, `F2`, ...) so it can be referenced across the smoke checklist, PR comments, follow-up issues.

```
**F1** — <one-line plain-language summary>
  - **Repro:** <minimal click path or commands>
  - **Workaround:** <what user does today>
  - **Fix idea:** <approach sketched, not coded>
  - **Tier:** S1 / S2 / S3
```

## PR description appendix

The handoff doc's last section is a copy-paste PR body. Standard shape:

```markdown
## Summary
<§1 bullets verbatim>

## How to verify
- Automated: `make phase-checks PHASE=X.Y` (BE N, FE M, E2E K/K — all pass)
- Manual: see `docs/handoff/YYYY-MM-DD-phase-X.Y-handoff.md` §4

## Known limitations
<§7 short summary by tier>

## Deploy note
<if migrations / env / secret changes — call out explicitly>

## Refs
- Spec: `docs/superpowers/specs/<phase-design>.md`
- Plan: `docs/superpowers/plans/<phase-plan>.md`
- Handoff: `docs/handoff/<handoff>.md`
```

## Anti-patterns

- Writing the handoff doc AFTER the PR was opened — you lost the chance for it to drive PR review.
- Putting raw commit messages into §1 — those are for §3, not §1.
- Listing every changed file in §3 without grouping (new / modified / migrations / api / commits).
- Skipping §7 because "everything works" — say "none open" explicitly so reviewers know findings were considered.
- Writing §2 as a smoke checklist — §2 is daily use ("how do I actually use this feature"), §4 is verification ("how do I prove it works").

## Why this exists

Product owners shouldn't need to read code to merge a PR. The handoff doc is the boundary contract: AI says "this is shippable, here's what changed, here's how to confirm." Owner reads 5 minutes, decides merge or not, and is the one who runs the manual smoke for surfaces that browser-only verification can catch (visual polish, real-feel UX, edge cases not in the test matrix).

Without this doc, every phase requires the owner to re-derive the same understanding from git log + code, which doesn't scale across many phases.
