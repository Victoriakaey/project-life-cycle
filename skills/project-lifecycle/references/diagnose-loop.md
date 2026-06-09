# Diagnose Loop — Hard Bug + Perf Regression Discipline

6-phase loop for hard bugs. Adopted from Matt Pocock's `diagnose` skill ([mattpocock/skills](https://github.com/mattpocock/skills)). Triggered when phase work hits a bug or regression that doesn't yield to a quick read.

**Relationship to `superpowers:systematic-debugging`:** this is project-lifecycle's actionable port. Use this doc when working inside the project-lifecycle skill (phase context, journal entry, regression test go into phase artifacts). Use `superpowers:systematic-debugging` standalone for ad-hoc debugging outside a phase. Same underlying philosophy (root-cause first); this version is more actionable on feedback-loop construction + log tagging.

**Iron Law:** no fix without root cause. Skip phases only when explicitly justified.

**3-Fix Rule:** after 3 failed fix attempts, pause + reassess assumptions or expand the search. Don't keep swinging.

## Phase 1 — Build a Feedback Loop (THE SKILL)

**This is the skill.** Everything else is mechanical. If you have a fast, deterministic, agent-runnable pass/fail signal for the bug, you will find the cause — bisection, hypothesis-testing, and instrumentation all just consume that signal. If you don't have one, no amount of staring at code will save you.

Spend disproportionate effort here. **Be aggressive. Be creative. Refuse to give up.**

### Loop Construction — try in roughly this order

1. **Failing test** at whatever seam reaches the bug — unit / integration / e2e
2. **Curl / HTTP script** against a running dev server
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot
4. **Headless browser script** (Playwright / Puppeteer) — drives the UI, asserts DOM/console/network
5. **Replay a captured trace** — save real network request / payload / event log to disk; replay through the code path in isolation
6. **Throwaway harness** — minimal subset of the system (one service, mocked deps) exercising the bug path with a single function call
7. **Property / fuzz loop** — for "sometimes wrong output" bugs: run 1000 random inputs, look for failure mode
8. **Bisection harness** — if bug appeared between two known states (commit / dataset / version), automate "boot at state X, check, repeat" so `git bisect run` works
9. **Differential loop** — same input through old-version vs new-version (or two configs), diff outputs
10. **HITL bash script** — last resort. If human must click, drive THEM with a structured loop so captured output feeds back

Build the right feedback loop → bug is 90% fixed.

### Iterate on the Loop Itself

Once you have *a* loop, ask:

- Can it be faster? (cache setup, skip unrelated init, narrow test scope)
- Can the signal be sharper? (assert on the specific symptom, not "didn't crash")
- Can it be more deterministic? (pin time, seed RNG, isolate filesystem, freeze network)

A 30-second flaky loop is barely better than no loop. A 2-second deterministic loop is a debugging superpower.

### Non-deterministic Bugs

The goal is not a clean repro but a **higher reproduction rate.** Loop the trigger 100×, parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable; 1% is not — keep raising the rate until it's debuggable.

### When You Cannot Build a Loop

Stop. Say so explicitly. List what was tried. Ask the user for: (a) access to the env that reproduces, (b) a captured artifact (HAR file / log dump / core dump / screen recording w/ timestamps), or (c) permission to add temporary production instrumentation.

**Do NOT proceed to hypothesise without a loop.**

## Phase 2 — Reproduce

Run the loop. Watch the bug appear.

Confirm:

- [ ] The loop produces the failure mode the **user** described — not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic, at a high enough rate to debug against).
- [ ] The exact symptom is captured (error message / wrong output / slow timing) so later phases can verify the fix actually addresses it.

Do not proceed until you reproduce.

## Phase 3 — Hypothesise

Generate **3–5 ranked hypotheses** before testing any. Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis MUST be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen it.

**Show the ranked list to the user before testing.** They often have domain knowledge that re-ranks instantly ("we just deployed a change to #3") or know hypotheses they've already ruled out. Cheap checkpoint, big time saver. Don't block on it — proceed with your ranking if user is AFK.

## Phase 4 — Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **Debugger / REPL inspection** if env supports it — one breakpoint beats ten logs
2. **Targeted logs** at the boundaries that distinguish hypotheses
3. Never "log everything and grep"

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch:** for performance regressions, logs are usually wrong. Instead: establish a baseline measurement (timing harness / `performance.now()` / profiler / query plan), then bisect. Measure first, fix second.

## Phase 5 — Fix + Regression Test

Write the regression test **before the fix** — but only if there is a **correct seam** for it.

A correct seam exercises the **real bug pattern** as it occurs at the call site. If the only available seam is too shallow (single-caller test when bug needs multiple callers; unit test that can't replicate the chain that triggered the bug), a regression test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The codebase architecture is preventing the bug from being locked down. Add to project backlog as a refactor candidate (no formal arch-refactor skill exists in project-lifecycle yet — log it in the deferred-decisions backlog file w/ Trigger + Exit criteria per the Mandatory Conventions in SKILL.md).

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam
2. Watch it fail
3. Apply the fix
4. Watch it pass
5. Re-run the Phase 1 feedback loop against the original (un-minimised) scenario

## Phase 6 — Cleanup + Post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run Phase 1 loop)
- [ ] Regression test passes (or absence of seam is documented)
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)
- [ ] The hypothesis that turned out correct is stated in the commit / PR message — so the next debugger learns

**Then ask: what would have prevented this bug?** If the answer involves architectural change (no good test seam / tangled callers / hidden coupling), log it in the deferred-decisions backlog w/ Trigger + Exit criteria. Make the recommendation **after** the fix is in, not before — you have more information now than when you started.

## When to Invoke vs Quick Fix

| Situation | Use diagnose loop? |
|---|---|
| Typo / one-line obvious cause | No — fix inline |
| Test failed once, can't repro | No — investigate; if repro elusive, then yes |
| Test failed reproducibly + cause unclear | Yes |
| Production incident | Yes |
| Perf regression | Yes |
| Flaky test you can't make deterministic | Yes (focus Phase 1 on raising repro rate) |
| 2nd / 3rd fix attempt failed | Yes — 3-Fix Rule kicked in |

## Anti-patterns

- **Skipping Phase 1** because "I can see the bug in the code" — without a loop, your fix is a guess. Build the loop.
- **Single hypothesis** — anchoring bias. Always 3-5 ranked.
- **Hypothesis that's not falsifiable** — "maybe it's a race condition" with no prediction = vibe. Sharpen or discard.
- **"Log everything"** — noise drowns the signal. Targeted logs at hypothesis boundaries.
- **Untagged debug logs** — survive into prod. Always `[DEBUG-xxxx]` prefix.
- **Fix without regression test when seam exists** — bug ships again next time the area is touched.
- **Marking done w/ debug instrumentation still in code** — `grep` your tag before declaring done.
- **Iron Law violation** — fix proposed before repro + ranked hypotheses. Stop, back up, build the loop.
