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
| 3 | **What changed** | New files + modified files + migrations + API surface changes + commit index + CONTEXT.md term additions/sharpening + new ADRs (link to `docs/adr/NNNN-*`) | Reviewer / future-you |
| 4 | **Manual smoke** | Link to the full Track A checklist + 5-line summary of headline steps | Product owner (runs it) |
| 5 | **Automated smoke** | `make phase-checks PHASE=X.Y` output (or equivalent) + last result + branch sha | Reviewer (already ran) |
| 6 | **Code-level tests** | BE + FE unit/integration test counts (per project's test runners) + new test file list | Reviewer (already ran) |
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

The handoff doc's last section is a copy-paste PR body. **MANDATORY 3-section shape, in this order:**

```markdown
## TL;DR

**Plain-language, 4-6 sentences, ZERO jargon — at the very top, before
everything else.** Written for someone who does NOT know this part of the
code and is skimming to learn "what did this PR actually do." Any technical
term (conflict-guard / topology-blind / I≈0 / bucketer / etc.) is either
avoided OR immediately followed by a plain-English gloss in parentheses.
Fixed four-part shape, in this order:

- **Problem** — what was wrong / missing before. Describe the *symptom* a
  human would notice, NOT the code.
- **What we did** — what this PR changes, described by *effect*, not
  implementation.
- **Why we did it** — the motivation or trade-off that made THIS change
  the right one (and not something else), in plain words. NOT an
  implementation justification — that's §2's job; this is the one-sentence
  "because" a skimmer needs to judge whether the change makes sense.
- **Result + honest boundary** — what's better now, AND explicitly what we
  did NOT do / could not do. Especially required when the deliverable is
  "acknowledging a limit" — say what the limit is, in plain words.

This is for the skimmer, NOT the reviewer. The technical sections below
(§1-§3, oracle evidence, ACs) stay unchanged for reviewers who want to dig in.

## 1. What was done

**Plain-English summary first (2-4 sentences).** Describe what this PR
adds / changes / fixes in human language — what does a user / reviewer
see after merge that they didn't see before? No file paths in the
summary; this is the elevator pitch.

### Use cases (REQUIRED for new user-facing features)

When the PR ships a NEW user-facing capability (CLI / slash command /
endpoint / UI surface / public API), include a "Use cases" subsection
under §1 with these three pieces:

1. **Scenario table** — 4-6 concrete real-world situations + the exact
   command / action a user runs in each. No abstraction. Format:
   `| Scenario | Command |`
2. **Comparison to existing surfaces** — 2-4 bullets explaining how
   this new feature differs from features that already exist in the
   project (what role does it play that's NOT covered by today's
   tooling?). Anchors the reader to existing mental model.
3. **Alternatives the user might reach for + why those are worse** —
   2-3 bullets pre-empting "but couldn't I just <X>?" questions.

Skip this subsection ONLY for refactors / bug fixes / pure-infra PRs
(no new user surface). When in doubt: include it.

### Files

File-by-file bullet list:
- `path/to/file.ts` (NEW / M, LOC delta) — one-line describe of what's in it
- 3-8 bullets typical; one concept per bullet

## 2. Why this approach
- design decision: which spec/plan question this answers
- trade-off: chose A over B because <reason>
- engineering alternatives considered + why rejected (distinct from
  §1 user-facing alternatives — §2 is about implementation choices,
  §1 use-case alternatives are about UX competing with existing tools)

## 3. Requirements satisfied
- ✅ spec §X.Y — what spec section / DoD item this closes
- ✅ plan task N — what plan task this completes
- ⚠️ partial: <which DoD remains open + why>

## Changelog + label (MANDATORY pre-merge checklist)
- [ ] Added one-line bullet to `CHANGELOG.md` `[Unreleased]` under right Keep-a-Changelog category (Added / Changed / Deprecated / Removed / Fixed / Security) — OR PR is exempt (internal refactor with zero user-visible delta, in which case apply `chore-quiet` / `skip-release-notes` label)
- [ ] Applied exactly one category label from `references/changelog.md` taxonomy (`breaking` / `feature` / `new-reference` / `new-command` / `cadence` / `workflow` / `convention` / `bug` / `fix` / `docs` / `ci` / `tooling` / `dependencies` / `chore` / `skip-release-notes`)
- [ ] PR title in Conventional Commits style (`feat:` / `fix:` / `feat!:` for breaking / `docs:` / etc.) — this is what auto-release-notes surfaces
```

### Demo — real console output (REQUIRED when the phase's surface is console / CLI / log / REPL output)

When what the user actually "sees" is terminal output (CLI tools, scripts,
log-driven workflows, REPLs, anything without a GUI), paste the **actual
captured stdout of a real run** into the PR — not a summary, not "13 passed".
This is the *demo receipt*: a reviewer reads what the change produces without
checking out the branch. Three pieces:

1. **Changed → result framing** — 2 lines: `Changed: <what>. Result: <what you now see>.`
   Anchors the reader before the raw dump.
2. **The run** — the exact command, then its real stdout. Keep the money-shot
   (the verdict / score / key result line) visible; collapse long dumps
   (full generated text, big tables) inside `<details><summary>…</summary>` so
   the comment stays scannable.
3. **Tests as a behavior list** — `pytest -v` / `vitest` / etc. per-test names,
   each with a one-line `# what this guarantees` comment, so the reviewer sees
   WHICH behaviors are locked in — not just a pass count.

Capture verbatim (`cmd 2>&1 | tee /tmp/demo.txt`); never hand-retype output
(retyped output is unverifiable + drifts). Post it as a PR **comment** (or in
this appendix) so it's attached to the PR, not lost in chat. Skip only for
pure-infra / non-observable phases (no console/GUI surface a human watches).

**Optional sections after the mandatory 3** (in this order):

```markdown
## Test plan
- [x] `make phase-checks PHASE=X.Y` (BE N, FE M, E2E K/K — all pass)
- [x] Manual: see handoff §4
- [ ] Reviewer: <specific ask>

## Known issues / carry-forward
<§7 short summary by tier; pre-existing failures NOT from this PR; action items deferred>

## Deploy note
<if migrations / env / secret changes — call out explicitly>

## Refs
- Spec: `docs/superpowers/specs/<phase-design>.md`
- Plan: `docs/superpowers/plans/<phase-plan>.md`
- Handoff: `docs/handoff/<handoff>.md`
```

**Why 3 mandatory sections:** mirrors the Task Close Report template
that gates every code commit
in projects that adopt it. Same 3 fields → no AI re-derivation cost
between commit-time and PR-time. PR body becomes the durable record
once merged; Task Close Report is the pre-commit checkpoint.

**Section §1 prose intro is non-negotiable** — bullets alone don't
tell a reviewer what the PR actually does. "src/cli/doctor.ts (NEW)
— 7 check functions" leaves the reviewer to assemble the picture.
A 2-sentence elevator pitch up front gives the picture, then bullets
fill in the detail.

**TL;DR is non-negotiable AND distinct from §1.** Different audience,
different register. TL;DR = the skimmer who does NOT know this code; zero
jargon; gloss any term in parentheses; fixed Problem / What we did / Why we
did it / Result + honest boundary shape. §1 = the reviewer about to read
the diff; project
vocabulary allowed, file-level detail follows. Do NOT collapse the two — a
jargon-free TL;DR that an outsider reads is the point. If the PR's whole
deliverable is "we admit a limit we couldn't fix," the TL;DR's Result line
states that limit in plain words, not as a buried caveat.

## Anti-patterns

- Writing the handoff doc AFTER the PR was opened — you lost the chance for it to drive PR review.
- Putting raw commit messages into §1 — those are for §3, not §1.
- Listing every changed file in §3 without grouping (new / modified / migrations / api / commits).
- Skipping §7 because "everything works" — say "none open" explicitly so reviewers know findings were considered.
- Writing §2 as a smoke checklist — §2 is daily use ("how do I actually use this feature"), §4 is verification ("how do I prove it works").

## Why this exists

Product owners shouldn't need to read code to merge a PR. The handoff doc is the boundary contract: AI says "this is shippable, here's what changed, here's how to confirm." Owner reads 5 minutes, decides merge or not, and is the one who runs the manual smoke for surfaces that browser-only verification can catch (visual polish, real-feel UX, edge cases not in the test matrix).

Without this doc, every phase requires the owner to re-derive the same understanding from git log + code, which doesn't scale across many phases.
