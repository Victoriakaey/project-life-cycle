# Verify-Loop Pattern

> "Give Claude some way to check its work — a unit test, a screenshot, a curl response — and it will iterate. If you give it a mock and say 'build this web UI,' it gets it pretty good. If you let it iterate two or three times, often it gets it almost perfect." — Boris Cherny, Anthropic

The single highest-leverage pattern in agentic coding. Most one-shot prompt failures are not the LLM's fault — they're a failure to wire a feedback channel.

## The pattern

```
LLM produces candidate output
         ↓
LLM runs an automated check (test / screenshot / curl / lint / diff vs spec)
         ↓
Check returns concrete signal (pass / fail with error string / image bytes / response body)
         ↓
LLM reasons about the signal and produces a better candidate
         ↓
loop until check passes (or N iterations, or human stops)
```

The LLM does NOT need a human in the loop — but it DOES need a tool that returns a deterministic signal it can react to. **Without a verify step, the LLM marks "done" based on its own opinion. With one, it iterates against reality.**

## Three canonical loops

### Loop A: Test loop (for logic / API / data)

- **Verify step**: unit test or integration test runs after each candidate.
- **Signal**: test runner output (pass count, fail count, error message + stack trace).
- **Where this lives in this skill**: cadence step 1.5 (acceptance verifier writes black-box tests per AC) + step 1 (vertical-slice TDD: 1 test → minimal impl → next test).
- **Anti-pattern**: LLM writes test + implementation in one pass without running the test; passes by coincidence; ships wrong behavior.

### Loop B: Visual loop (for UI / layout / mockups)

- **Verify step**: screenshot the rendered UI (Playwright, Puppeteer, iOS simulator, browser-use, etc.) and feed the image back into the LLM's context.
- **Signal**: rendered pixels — LLM sees what the user sees.
- **Where this lives in this skill**: smoke-tracks.md Track B (Playwright spec captures screenshots/videos/traces; LLM consumes them on re-run).
- **Anti-pattern**: hand the LLM a mockup, get back code, never render it, ship UI that looks nothing like the mock.

### Loop C: Runtime loop (for integration / contracts / live behavior)

- **Verify step**: start the dev server / queue / DB, hit it with `curl` / `bun run` / `pytest -k integration`, capture the response.
- **Signal**: HTTP status + body, log lines, queue state, DB row deltas.
- **Where this lives in this skill**: `references/smoke-tracks.md` Track A (live checklist run); cadence step 1 builder pre-flight runs the project's smoke command before declaring DONE.
- **Anti-pattern**: builder writes endpoint + claims DONE, never actually curls it, returns 500 in prod.

## Wiring a verify loop into any subagent dispatch

When dispatching ANY subagent in this skill's cadence — builder, acceptance verifier, validator, ship orchestrator — include explicit instructions for the loop:

```
You have access to a verify step:
  - Tool: <test runner | screenshot tool | curl + server>
  - Run after every candidate before declaring DONE.
  - On FAIL: read the error, revise the candidate, re-run.
  - Cap: <N> iterations. After N, report BLOCKED with the latest failure
    and let the controller decide whether to expand scope or change approach.
  - On PASS: report DONE with the verify output attached as evidence.
```

Without the explicit cap (N), the loop can burn budget. Default N = 3 for fast loops (tests), 2 for slow loops (visual/screenshot).

## Anti-patterns

- **No verify step in the dispatch** → LLM self-grades; lies become invisible; "done" is opinion. Always wire a tool, even a thin one (a single `make smoke` command).
- **Verify step returns "looks good" boolean instead of raw output** → LLM can't reason about what's wrong; reverts to guessing. Tools must return raw signal (error string, image bytes, response JSON).
- **One-shot dispatch on a non-trivial task** ("build the whole UI") without a screenshot loop → builder ships v1 that's 40% right; you spend 5x the budget on follow-up fixes that a 2-iteration loop would have caught.
- **Visual loop without a deterministic viewport** → screenshots vary by browser size / DPR / OS → LLM chases noise. Pin viewport + DPR in Playwright config.
- **Verify loop budget left uncapped** → LLM iterates forever on an impossible spec. Always cap; on BLOCKED, surface to controller for scope/approach decision.
- **Conflating verify with code review** → verify is "does the code achieve the goal" (signal from reality). Code review is "is the code well-built" (judgment from a peer). Both required; don't substitute one for the other.
- **Marking AC closed because the unit test passes** when the acceptance test (Loop A black-box from `references/cadence.md` step 1.5) doesn't exist or fails → unit test ≠ behavior verification. Both required for user-observable phases.

## Cross-reference

- `references/cadence.md` step 1 (vertical-slice TDD = Loop A in microcosm) + step 1.5 (acceptance verifier = Loop A at the AC level) + step 2 (validator confirms verify outputs are honest, not LLM self-graded).
- `references/smoke-tracks.md` — Track A manual + Track B Playwright (Loop B + C codified as deliverables).
- `references/diagnose-loop.md` — Phase 1 "build feedback loop first" is this pattern applied to bug-hunting. The diagnose loop IS a verify loop with the bug repro as the verify step.
- `references/builder-split.md` — Builder Summary's "Tests passing" section is the per-builder verify-loop evidence.
