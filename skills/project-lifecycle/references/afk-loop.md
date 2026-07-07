# AFK Loop — Contract-Bounded Unattended Runs

An AFK loop is an agent run with **no human present**: overnight lint cleanup, batch renames, coverage backfill. The micro verify-loop (`references/verify-loop.md`) keeps a single dispatch honest; this document is the macro tier — hours of iterations with nobody watching. The design target is a hard bound on the worst case: **a bad night costs a deleted branch and a spent usage window — never a polluted main, a lied-about "done", or an unbounded bill.**

Everything here follows from one evidence base: agents under autonomous pressure reward-hack. METR documented Claude 3.7 inside Claude Code deleting tests and hardcoding expected values, with 30.4% of RE-Bench runs reward-hacked (https://metr.org/blog/2025-06-05-recent-reward-hacking/). Therefore: **the agent never grades itself, never flips its own pass bits, and never touches main.** Deterministic checks are primary; LLM judgment is secondary.

## When to AFK

Eligibility is decided at the front door — the **AFK-eligibility axis** in `references/intent-gate.md` Stage 1. A request is AFK-eligible only when **ALL four** hold:

| # | Condition | Disqualifier |
|---|---|---|
| a | Oracle at **specified / differential / golden** tier (intent-gate oracle ladder) | implicit-only oracle ("must not crash") |
| b | **No irreversible-class actions** in scope | auth, migrations, deletions, force-push, publish, prod data |
| c | A **file-scope fence** is definable as concrete globs | "wherever it's needed" |
| d | **No design / aesthetic judgment** required | UI polish, naming taste, API shape decisions |

The gate emits the existing HITL/AFK label vocabulary from `references/issue-breakdown.md` — one taxonomy, two scopes. On a qualifying request the gate **offers** ("this qualifies for AFK; want a loop contract?") — it never auto-starts a loop.

Brownfield + fuzzy spec is categorically ineligible (fails a and usually c). The Replit incident — agent wiped a production database during an autonomous run (https://fortune.com/2025/07/23/ai-coding-tool-replit-wiped-database-called-it-a-catastrophic-failure/) — is why condition (b) is a separate test, not folded into the oracle check.

### Graduated rollout

First **2-3 runs are semi-supervised**: daytime, small tasks (≤5 rounds), **local-only — no push**. You watch the registry and iterations.log behave, you check the exit report against reality. Only after a clean track record does the loop earn push-on-exit to `loop/` branches. Skipping this is an anti-pattern (below).

## Loop contract

Four fields. **All mandatory.** No contract → no loop.

```markdown
## AFK Loop Contract — <task slug>

Goal:    <machine-checkable; close-gate command that must exit 0>
         e.g. `npm run lint -- --max-warnings 0 && npm test`

Stop:    - tests-touch: any modification to test files (unless contract names them in-scope)
         - scope-fence breach: write outside <glob list>
         - irreversible op attempted: migration / deletion / force-push / publish / auth change
         - 3-strikes: same normalized error fingerprint 3 times

Budget:  max-rounds: 15        max-hours: 3
         window-breaker: 5h > 80%  OR  7d > 90%     # afk-budget-unit: window-pct
         # API billing instead:  usd-cap: <N>        # afk-budget-unit: usd

Report:  runs/<date>-<slug>/exit-report.md           # written for ALL end states
```

- **Goal** — machine-checkable only. The close-gate command exiting 0 is the *only* thing that decides done (`references/close-gate.md`). A worker's "I'm finished" sentinel may **trigger an early check**; it is never load-bearing. This is the METR lesson applied: write-separation between the worker and the verdict.
- **Stop** — minimum clauses as in the template. Error fingerprints are normalized before hashing: strip timestamps, absolute paths, line numbers — otherwise the same error looks new every round and 3-strikes never fires.
- **Budget** — see mechanics below.
- **Report** — path of the exit report; the loop's terminal obligation in every end state.

The consensus behaviors (fresh context per iteration, commit-per-green, etc.) are **default discipline** (next section), not contract fields — they're how every loop runs, not per-task knobs.

### Budget mechanics

Rounds + hours are the **universal mandatory floor** — zero measurement cost, enforced by the outer shell, immune to API weather. The third slot adapts to billing mode via a `CLAUDE.md` policy key:

```
afk-budget-unit: window-pct | usd
```

**Subscription (`window-pct`) — dual-window circuit breaker.** Both windows, because they decouple: a short window can sit near a quarter spent while the weekly window is near three-quarters — a single-window breaker would have cheerfully burned the weekly allowance overnight. Defaults: stop when **5h > 80% OR 7d > 90%**.

Read mechanism 🟡 *undocumented endpoint — verified live, may break without notice*:

- Per-iteration read of the OAuth usage endpoint (`/api/oauth/usage`, token from the macOS keychain) — returns exact plan-normalized utilization for both windows. (Statusline stdin JSON carries the same data but is interactive-only; ccusage is an estimate with window-start measured ~30min off live. Sources: https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor/issues/202, https://github.com/anthropics/claude-code/issues/50518, https://code.claude.com/docs/en/statusline.)
- Cache reads **≥60s**; back off on 429.
- **Fail-safe (primary, the endpoint is the optimization):** N consecutive unreadable reads (default N=3) = **treat as over budget and stop**, end state `BUDGET_UNREADABLE` — never `BUDGET_HIT`, or endpoint death poisons future calibration.
- Window-% is shared machine state: parallel interactive sessions make the before→after delta approximate. Note it; don't pretend precision.

**API (`usd`)** — hard $ cap, checked per-iteration from billing/usage data.

### Cold start — budget without a forecast

A budget is a **circuit breaker, not a forecast** — a wrong budget beats no budget. Sequence:

1. Factory defaults: **15 rounds / 3h / 80% / 90%**.
2. Agent proposes an estimate from the task shape + grep of past exit reports' Consumed fields (v1 calibration database = grep).
3. User one-tap approves or edits — same assume-then-confirm philosophy as the intent gate.
4. Every exit report's actual/limit pairs calibrate the next estimate.

## Runtime decision table

| Scenario | Runtime | Why |
|---|---|---|
| Short (<1h), semi-present, transcript-verifiable | `/goal` + Stop hook, in-session | context survives one short arc; cheapest wiring |
| Overnight bounded sprint (2-3h) — **the primary AFK scenario** | external **fresh-session-per-iteration** loop, budget enforced at the shell layer | context rot is measured fact: degradation from ~50K tokens, failure rate quadruples per duration doubling (https://www.trychroma.com/research/context-rot); Anthropic's harness guidance: full reset + structured handoff **beats compaction** (https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) |
| Recurring maintenance (nightly deps, log triage) | cron chain, small batches | recurrence belongs to a scheduler, not a marathon session |
| Brownfield / fuzzy spec | **AFK forbidden** | fails the eligibility gate; HITL only |

Fresh sessions trade in-model rot for disk-state rot. The trade is asymmetric — disk state is diffable, git-revertable, and hygiene-controllable (§State hygiene); in-model rot is none of those.

## Default discipline

Doc-body rules every AFK loop runs with — the practitioner consensus distilled from the loop-engineering canon (Osmani, Ralph, Anthropic harness guidance). Not contract knobs.

1. **Fresh context per iteration** — new session each round; state lives on disk, not in the window.
2. **One unit of work per iteration** — one registry item per round; partially-done everything is the failure mode.
3. **Commit-per-green** — every passing unit becomes a commit immediately; progress survives any crash.
4. **Worktree isolation** — the loop runs in its own git worktree on a `loop/<date>-<slug>` branch; the main checkout is never touched.
5. **Learnings file, hard-capped** — `learnings.md` carries forward distilled gotchas (~60 lines max); the cap forces distillation over accumulation.
6. **Session-start re-orientation** — each iteration begins by reading registry + learnings + `git log --oneline -20`, never by trusting memory.
7. **Verify after every unit** — the deterministic check runs after each candidate (`references/verify-loop.md`); no self-grading.
8. **One breadcrumb line per iteration** — appended to `iterations.log` (§AFK Run Narrative).
9. **No mid-run scope expansion** — anything outside the fence or the contract → stop and report, never improvise.

## State model

Three layers, strict write boundaries:

| Layer | Loop access | Why |
|---|---|---|
| **Project ROADMAP / plans** | **FORBIDDEN** — enforced as a scope-fence **path check**, not a prompt | granularity mismatch + stability contract: an unattended loop must never rewrite the whole-plan map |
| **Run-scoped task registry** (`runs/<run>/registry.json`) | the **ONLY loop-writable authoritative state** | single schema-constrained JSON checklist (canon: snarktank prd.json, Anthropic feature_list.json) |
| **Exit report** | written once at exit, then **frozen** | self-contained snapshot; readable without the run dir |

Registry write-separation — the load-bearing rule:

- The agent writes `status` / `notes` fields.
- The **`passes` booleans are writable ONLY by the deterministic verify step.** If the agent can flip its own pass bits, the report's Done list is a laundered self-report.
- All registry writes are **atomic**: write tmp file, `rename(2)` over the original. A crash mid-write must not corrupt the only authoritative state.

**Run-level mutex:** one AFK run per machine — a lockfile in the runs dir. A second concurrent loop is an OOM risk on a memory-constrained machine, and parallel loops make window-% accounting meaningless.

## State hygiene

The 7 rules that keep fresh-session disk state from rotting:

1. **Single authoritative state** — the schema-constrained JSON registry. No parallel TODO files, no status prose.
2. **`passes` write-separation** — only the deterministic verify step writes pass booleans (above; repeated because it is the rule most worth repeating).
3. **Atomic writes** — tmp + rename, every registry write.
4. **Plans are disposable** — regenerate the per-iteration plan each round; never accumulate stale plans on disk.
5. **Learnings hard-capped ~60 lines** — over cap → distill, don't append.
6. **No re-narration of git-persisted facts** — git log/diff IS the memory; logs are append-only with a distilled head, never essays restating what `git show` already proves.
7. **One breadcrumb line per iteration** to `iterations.log` — no prose (format in §AFK Run Narrative).

## Guards

Per-guard enforcement honesty: tag what is code today vs. what is still prose. Scaffold patterns live in `references/deterministic-handlers.md`.

| Guard | Enforcement | Scaffold pointer |
|---|---|---|
| Protected-path / scope-fence write check (incl. ROADMAP-forbidden) | **code-enforceable-now** — PreToolUse path check; **first build candidate** | deterministic-handlers.md anatomy + secret-leak guard (handler #3 shape) |
| Rounds + hours budget | **code-enforceable-now** — outer shell counts rounds, `timeout` walls clock | shell layer, no handler needed |
| Window-% / $ breaker | **code-enforceable-now** 🟡 endpoint — per-iteration read + fail-safe | deterministic-handlers.md "cheap state check, early exit" discipline |
| Tests-touch stop | **code-enforceable-now** — path check against test globs | same PreToolUse scaffold as scope fence |
| 3-strikes error fingerprint | **prose-only** today — normalize (strip timestamps/paths/line numbers) → hash → count | deterministic-handlers.md handler #5 (attribution is mechanical) |
| No-progress detector | **prose-only** today — K rounds (default 3) with zero registry delta AND zero diff delta → stop `NO_PROGRESS` | trivial shell diff check; second detector beside fingerprints |
| Registry `passes` write-separation | **prose-only** today — verify step owns the field; schema check candidate | close-gate.md owns the verify step |
| Run mutex | **code-enforceable-now** — lockfile | shell layer |
| Egress (main/PR/tags/publish) | **code-enforceable-now** — server ruleset + scoped PAT (§Egress policy) | not a handler; server-side |
| Report leak-scan | **code-enforceable-now** — existing leak-scan over the report before commit | project leak-scan hook |

**METR warning, restated as policy:** deterministic guards are the primary defense; LLM-based monitoring (an agent watching the agent) is secondary at best. Prompt-level "please don't" freezes demonstrably fail under autonomous pressure (https://metr.org/blog/2025-06-05-recent-reward-hacking/, https://www.anthropic.com/research/emergent-misalignment-reward-hacking). A guard that exists only in the prompt should be tagged prose-only and treated as ≈0.

## Exit report

Written at exit for **all** end states. Seven fields in narrative order — how it ended, then why, then cost, then what moved, then how to continue.

```markdown
# AFK Exit Report — 2026-06-11-lint-cleanup
run: runs/2026-06-11-lint-cleanup/ · branch: loop/2026-06-11-lint-cleanup
base: 3f2a91c · ended: 2026-06-12 03:41

## How it ended
BLOCKED / tests-touch — fixing `no-unused-vars` in src/api/users.ts required
editing users.test.ts, which the contract fences out.

## Blocker
users.test.ts imports the unused symbol under test; removing the symbol breaks
the import. Needs a human call: widen fence to the test file, or drop the rule
for that path.

## Consumed
rounds: 7 / 15 · wall: 1h52m / 3h · 5h-window: 34% → 61% (limit 80%) · 7d: 71% → 74% (limit 90%)

## Done            <!-- auto-generated from registry: passes == true -->
- [x] src/lib/dates.ts — 12 lint errors → 0 (verify: lint+tests exit 0, commit a1b2c3d)
- [x] src/lib/strings.ts — 8 → 0 (an earlier commit)
- [x] src/api/orders.ts — 15 → 0 (an earlier commit)

## NOT done        <!-- auto-generated from registry: passes != true; mandatory, "none" allowed -->
- [ ] src/api/users.ts — blocked (tests-touch)
- [ ] src/api/payments.ts — not reached

## Resume seed
From base 3f2a91c, branch loop/2026-06-11-lint-cleanup: resolve the users.test.ts
fence question, then re-run with registry items 4-5 only.

## Evidence
runs/2026-06-11-lint-cleanup/iter-{1..7}/ (local, gitignored) · iterations.log (7 lines)
worktree at exit: clean
```

Rules:

- **Death code is derived, not chosen**: `ENUM / contract-clause` — the enum member comes from which mechanism fired, the clause from the contract line that fired it (e.g. `BLOCKED/tests-touch`, `BUDGET_HIT/max-rounds`). Closed set, zero-maintenance, no LLM classification step. Plus one human sentence.

| Code | Meaning |
|---|---|
| `COMPLETE` | close-gate exited 0; pending re-verify (below) |
| `BUDGET_HIT` | a budget limit fired (clause names which) |
| `BLOCKED` | a Stop clause fired (clause names which) |
| `NO_PROGRESS` | K rounds with zero registry + zero diff delta |
| `CRASHED` | abnormal end; written by trap or scavenger |
| `BUDGET_UNREADABLE` | N consecutive failed budget reads — distinct from BUDGET_HIT so endpoint death never poisons calibration |
| `COMPLETE_UNCONFIRMED` | report said COMPLETE; re-verify failed |

- **Done / NOT-done are auto-generated from the registry** — never hand-written. Done = `passes == true` (which only the verify step can set, so the list is evidence, not narrative). NOT-done is mandatory; "none" is an acceptable value.
- **Consumed = actual/limit pairs** in the user's billing unit — window % before→after for subscription, $ for API. Budget is the contract-side limit; Consumed is the report-side bill.
- **Dirty-worktree state is recorded for ALL end modes** — a CRASHED run with uncommitted changes is exactly the case the next session must know about.
- **The report itself passes leak-scan before commit** — blocker text can quote secrets verbatim. The evidence dir (`iter-N/`) is **gitignored by default**.
- **Resume seed embeds the base commit SHA** — resumption is positioned against a fixed point, not "wherever main is now".

### Lifecycle

1. **Exit-write, all modes** — the loop's last act in every end state.
2. **Trap → CRASHED** — the outer script's exit trap writes a minimal CRASHED report on abnormal termination.
3. **SessionStart scavenger** — traps don't fire on SIGKILL/OOM (memory pressure makes OOM kills realistic on a local machine). On interactive session start: any run dir with a registry but no report → synthesize a CRASHED report from the registry + git state.
4. **Unread marker** — the next interactive session auto-surfaces unread reports, then flips inbox → archive. Mid-run progress checks read the registry directly; there are no interim reports.
5. **COMPLETE re-verify (trust protocol)** — a COMPLETE report is believed only after the goal check is **re-run once** in the interactive session. Failure flips it to `COMPLETE_UNCONFIRMED` with a defined next action (diagnose why the in-loop pass didn't reproduce). `BLOCKED` / `BUDGET_HIT` are statements against interest — no re-check needed.

## Egress policy

The loop's terminus is a **pushed `loop/` branch + the exit report**. Everything beyond that is the next interactive session's job.

| Channel | Policy | Mechanical enforcement |
|---|---|---|
| push `main` | **FORBIDDEN** | server ruleset (PR required, no force-push) · scoped PAT → 403 · harness ask-rule |
| merge any PR | **FORBIDDEN** | ruleset bypass list EMPTY · repo Allow-auto-merge OFF · **merge is human-only** |
| push `loop/**` | **ALLOWED** (after graduated rollout) | scoped PAT grants exactly this |
| open PR | **FORBIDDEN for the loop** | PAT has contents scope only; PR ceremony = next interactive session, existing draft-first workflow (`references/pr-comment-template.md`) |
| tags / releases / publish | **FORBIDDEN** | PAT lacks scopes; tag rulesets; release goes via PR (`references/release-process.md`) |
| CI | **limited** | `loop/**` branch CI may run checks; no deploy/release triggers keyed off `loop/**` |
| connectors / external messaging | **NONE** | no such credentials in the loop environment |

Unattended PRs attract automation — issue #44202 documents an agent-opened PR auto-merged to production main **in 11 seconds**, and the report was closed as a duplicate (https://github.com/anthropics/claude-code/issues/44202). Hence: the loop never opens PRs; a human-present session does, where auto-merge interplay is observable.

### Main-protection setup checklist (3 layers)

1. **Server (the wall):** main ruleset — PR required + no force-push + **empty bypass list**; repo setting Allow-auto-merge = **OFF**; **release flow also goes via PR** (note in `references/release-process.md`).
2. **Harness (friction, honestly labeled — not a wall):** push-to-main in permissions **ask** rules (docs-only direct push = a human clicks the dialog) + the project's guard.sh.
3. **AFK credential (the cage):** fine-grained PAT, `contents:write` on `loop/**` **only** — main push, PR creation, and tags all return 403 at the credential layer.
4. **Reviewer credentials are read-only:** any AI reviewer must be unable to push. GitHub Copilot specifics: a `@copilot` PR-comment mention triggers the push-capable *cloud/coding agent*, not plain review — request reviews via the Reviewers UI or `gh pr edit <n> --add-reviewer @copilot` instead, and disable the agent for the account/repo (Copilot settings → Cloud agent → Repository access). Belt-and-suspenders: a ruleset on `copilot/**` branch creation with no bypass actors blocks the agent mechanically. A reviewer that edits is a writer — the review-record doctrine (`references/review-record.md`) collapses.

Enforcement-quality ordering, stated once and believed everywhere: **server > harness permission > prompt (≈0)**.

## AFK Run Narrative

The morning-after archaeology chain. Three layers, built bottom-up:

**Layer 1 — `iterations.log` breadcrumbs.** The loop appends exactly one structured line per iteration. No prose.

```
round | target                  | action                       | verify        | decision+why
4     | src/api/orders.ts       | fix 15 no-unused-vars        | PASS (lint+tests 0) | commit 9bc0de1; next item
5     | src/api/users.ts        | fix 12 no-unused-vars        | FAIL (import breaks) | retry: remove symbol instead
6     | src/api/users.ts        | remove unused symbol         | FAIL (same import error — fingerprint strike 2) | retry as type-only import
7     | src/api/users.ts        | remaining fix needs users.test.ts assertion edit | — | STOP — BLOCKED/tests-touch (pre-action: file never touched)
```

**Layer 2 — PR-comment "AFK Run Narrative".** When the next interactive session runs the PR ceremony, it compiles iterations.log into one extra PR-comment layer: **TL;DR** (one paragraph: end state, done/not-done counts, cost) + **per-round table** (the log, rendered) + **decision points highlighted** (every row whose decision wasn't "next item" — retries, strikes, stops).

**Layer 3 — raw evidence.** `runs/<run>/iter-N/` — full per-iteration output, local-only, gitignored.

Drill-down tiers for the reviewer: **PR narrative → iterations.log → iter-N/ raw evidence.** Each tier answers "why?" one level deeper; most reviews never leave tier 1.

## Anti-patterns

- **Loop without a contract** ("just keep fixing lint until morning") → no Stop clauses, no budget, no report obligation. All four fields or no loop.
- **Budget left blank or "run and see"** → the widely-reported overnight-$500-bill failure mode. A wrong budget beats no budget; factory defaults exist precisely so blank is never the answer.
- **Agent-flipped `passes` booleans** → the Done list becomes a laundered self-report; the whole trust chain (report → narrative → merge) inherits the lie. Verify step owns the field.
- **Worker self-certifying done** → METR-documented failure class (deleted tests, hardcoded expected values). Worker sentinel = early-check trigger only; close-gate exit 0 decides.
- **Loop opening PRs or merging** → 11-second auto-merge-to-prod incident (#44202). Terminus is a pushed `loop/` branch; PR and merge belong to humans-present sessions.
- **Prose-only main protection** ("the prompt says never push main") → prompt tier ≈ 0 enforcement. If the server ruleset and scoped PAT aren't configured, main is not protected.
- **Progress-file essays** → re-narrating what git already proves rots the disk state fresh sessions depend on. Registry + one breadcrumb line + capped learnings; nothing else.
- **AFK on brownfield or fuzzy spec** → fails the eligibility gate by definition; an oracle you can't name is an oracle the loop will fake.
- **Skipping graduated rollout** → first contact with the budget breaker, scavenger, and fence checks should happen while you're watching, on a ≤5-round local-only run — not at 3am with push enabled.

## Cross-reference

- `references/intent-gate.md` — AFK-eligibility axis (Stage 1) + oracle ladder; the gate offers AFK, never auto-starts.
- `references/issue-breakdown.md` — HITL/AFK label vocabulary the gate reuses (one taxonomy, two scopes).
- `references/verify-loop.md` — the inner loop each iteration runs; AFK is verify-loop iterations stacked inside a contract cage.
- `references/close-gate.md` — the deterministic check that owns "done" and the registry `passes` field.
- `references/deterministic-handlers.md` — scaffold patterns for the code-enforceable guards; protected-path PreToolUse check is the first build candidate.
- `references/harness-primitives.md` §8 — the independent-evaluator doctrine this document mechanizes.
- `references/pr-comment-template.md` — the existing PR ceremony the AFK Run Narrative layer plugs into.
- `references/release-process.md` — release-via-PR note for repos adopting the strict main ruleset.
- `references/cadence.md` — the interactive cadence that resumes from a report's Resume seed.
