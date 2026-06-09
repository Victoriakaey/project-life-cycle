# Intent Gate — the workflow front door

The first thing that runs on **any fresh user request inside this workflow** — milestone kickoff *and* mid-phase ad-hoc instructions ("now fix this modal"). It turns a fuzzy human ask into a confirmed **intent**, then a precise executable **prompt**, before any code is written. Two jobs: **(a)** turn fuzzy dissatisfaction into a precise root-cause + explicit expectation; **(b)** verify the fix against an external oracle, not self-assessment (Stage 3).

It also doubles as the **machinery triage**: Stage 1's size axis decides whether the request earns the full Per-Phase Workflow, a per-task cadence, or just a one-liner — the cure for over-invoking the heavy path.

Flow: **classify → confirm intent → reframe+sharpen**. Feeds the brainstorm (step 1) for large work, or the cadence directly for a single task.

## Stage 1 — Classify (read-only)

Runs as a read-only pass in the main loop, NOT a subagent (cost). Discipline: no file writes before the reframe is confirmed.

| Axis | Cheap signal | Effect |
|---|---|---|
| **Ambiguity** (CLAM) | underspecified? multiple readings? | ambiguous → stage 2; **default is assume, NOT ask** |
| **Already-precise** | user already wrote a sharp spec | skip gate → one-line "I read this as X", go straight to the cadence |
| **Size** | trivial / medium / large | trivial+clear → skip the workflow, one-line "I read this as X", do it inline; medium → per-task cadence; large → seed brainstorm (step 1) |
| **Reversibility** | delete / migrate / publish / state change | irreversible → always confirm, even if 1 line |
| **Continuation** | same task as the active thread? | continuation → one-line restate only, no full ceremony |

## Stage 2 — Confirm intent

**Default aggressiveness = `assume`** (lay out assumptions; ask only when genuinely blocked).

1. Step-back: name the problem class — **bug / missing-capability / design-choice / scope-undefined**
2. Restate: "I read your intent as X"
3. **Default path (ambiguous but assumable):** lay out the specific assumptions filling the blanks → user one-tap approve or corrects only the wrong line.
4. **Exception path (ask):** ask **one** highest-Gain/Q question ONLY when a key ambiguity cannot be resolved by a reasonable assumption and getting it wrong would require redoing significant work.

**Brainstorm handoff:** large work → seed `superpowers:brainstorming` (Per-Phase Workflow step 1) with the confirmed intent. Do NOT re-ask intent downstream — the gate's confirmed intent IS the brainstorm seed. (Gate = first 10 seconds of a big job; full lifetime of a small one.)

## Stage 3 — Reframe + sharpen

Self-refine (whole block, once): before surfacing to the user, critique the drafted prompt against the oracle ladder + the wrong-if clause — is the oracle the strongest available? is the root cause mechanism-level or still a symptom? is the scope minimal? Fix inline, then surface. One pass, not a loop.

```
[Problem]   symptom + expectation. Now X, should Y.
            wrong-if: this is wrong if <Z>          ← falsifiable clause
[Root cause (hypothesis)]   mechanism-level + evidence anchor
            (a log line / a specific var / a file:line).
            If unsure: "Suspect X — investigate before changing."
[Scope]     change only <files>; don't touch <rest>. Separate commit.
[Oracle]    name the STRONGEST available type (see Oracle ladder):
            specified > differential/golden > metamorphic > implicit.
[Verify]    reproduce <action> → screenshot/output → diff against oracle →
            paste evidence + "matches/differs". One thing at a time.
```

For a large request, this sharpened block becomes the seed the brainstorm + `user-story.md` expand on (numbered ACs = the formal version of the expectation + oracle). For a single cadence task, it becomes the task text + ACs handed to the implementer.

## Oracle ladder

| Type | Use when | Example |
|---|---|---|
| **specified** | a spec / ticket / API contract / prototype exists | diff against §X of the spec, or `Prototype.html` |
| **differential** | a prior version or independent impl should agree | compare old build vs new; two impls of same function |
| **golden / snapshot** | a known-good output can be frozen | committed screenshot / recorded stdout / snapshot test |
| **metamorphic** | exact output unknowable, but invariants hold | `f(x) == f(transform(x))`; sort then reverse |
| **implicit** | nothing else exists — always available, weak | must not crash / leak / throw type error |

**No-oracle branch (explicit):** when none of specified/differential/golden applies and the request is a new capability, choose one of:
1. **manufacture** a golden/snapshot now (capture the intended output as truth), or
2. **flag low confidence** — "this is judged by vibes; accept that," or
3. **reclassify** — recognize "this isn't a bug, it's a missing Phase" and route it to brainstorming as a new phase rather than patching.

Treat a fabricated, confident-but-wrong oracle or root cause as worse than admitting there is none. The gate must be allowed to say "I can't form a hypothesis — investigate first."

## Policy & escape

- **Project key** in `CLAUDE.md`: `intent-gate: ask | assume | off` (default `assume`).
- **Verbal bypass**: "skip gate" / "just do it" → execute without the gate this turn.
- **Auto-skip**: classifier detects an already-precise prompt → no ceremony.
- **Persistence**: trivial → not stored. Anything committed → the reframe block goes into the commit message or the iteration journal "Plan deviations"/context. Store inline with the code — zero new files, greppable.

## Relationship to the rest of the harness

The gate is the **front** of the pieces that already enforce precision deeper in the workflow — it doesn't replace them, it feeds them:

| Gate field | Downstream enforcer |
|---|---|
| confirmed intent | `superpowers:brainstorming` (step 1) |
| expectation / wrong-if | `user-story.md` numbered ACs |
| oracle | acceptance verifier (cadence 1.5) + validator (cadence 2) diff against the story |
| root-cause hypothesis | `diagnose-loop.md` (when the request is a bug) |
| restate-before-code | implementer pre-flight assumption block (cadence step 1) |
| language sharpening | `CONTEXT.md` glossary |
