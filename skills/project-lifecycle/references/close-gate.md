# Close Gate — the deterministic forcing function for "done"

The #1 failure mode of this skill: the AI finishes the *interesting* work (code that runs), feels done, and silently skips the wrap-up steps — journal, tests-3×, handoff, CHANGELOG, PR-comment. Prose "MANDATORY" does not stop this; the model treats prose as soft and the wrap-up steps are last in the list, furthest from attention by the time code works.

The fix is structural, per the skill's own rule (*structure > rules*): a **pure-code gate that exits non-zero when a required artifact is missing.** The model cannot lie past a script that greps for the journal file. This is the harness contract the rest of the skill promises — realized for wrap-up.

Two layers, used together:

1. **Visible state** — the AI materializes the step list as a TodoWrite at invocation (see SKILL.md "Definition of Done"). Unchecked wrap-up todos glare at done-time.
2. **Hard gate** — `task-done` / `phase-done` exits 1 on any missing required artifact. The AI MUST run it and paste the output before claiming the task/phase is complete. A pre-push hook makes it un-bypassable.

State #1 makes skips *obvious*; gate #2 makes them *impossible to hide*.

---

## What the gate checks

### `task-done` (one cadence task)
- [ ] a `feat(...)`/`fix(...)` commit exists for this task (not just staged/working-tree)
- [ ] a `docs:` journal commit exists in the branch range (`origin/main..HEAD`), and the journal entry contains the literal header `## Plan deviations` (present even if body = "none")
- [ ] a fresh, **non-empty** test-evidence file exists (mtime newer than the feat commit; `-s` not just `-f` — an empty-but-fresh file is a false pass, e.g. an interrupted `tee`) — written by the project's test runner, not by hand; if `test_runs_required` > 1 the file must also contain a `RUNS=N` line with N ≥ required. **Scope note:** after a fixup, task-level evidence may be scoped to the suites the fixup diff touched (per `cadence.md` §"Selective re-verification after fixup") — the scoping is task-level ONLY; `phase-done` below always demands full-suite evidence, and that full run is the safety net for anything task-level scoping skipped
- [ ] no orphan `[DEBUG-` logs remain in the diff
- [ ] **(Sweeper only)** if a commit in range carries an `Archetype: sweep` trailer, the code diff (`docs/**` + `CHANGELOG.md` excluded) is net-negative LOC **or** a `SWEEP-PERF: <evidence>` line is logged — see §"Sweeper diff-direction"
- [ ] if any artifact is absent, a `SKIP:` line with a reason exists in the journal "Plan deviations" section

### `phase-done` (phase close, before PR-merge)
- [ ] `user-story.md` exists for the phase (unless `exempt_user_story` true — refactor/docs/infra)
- [ ] spec doc + plan doc exist for the phase
- [ ] the journal file was touched in this phase's commit range (per-task completeness is a reviewer concern, not deterministically gated)
- [ ] handoff doc exists and contains all 8 section headers
- [ ] `CHANGELOG.md` `[Unreleased]` was touched in this phase's commit range (unless `exempt_changelog`)
- [ ] smoke artifacts exist — Track A checklist + Track B spec — when `user_visible` true
- [ ] acceptance tests exist for the phase (glob `acceptance_glob`), unless `exempt_user_story` true (cadence step 1.5)
- [ ] `docs/ROADMAP.md` touched in the phase's commit range
- [ ] **fresh, non-empty test-evidence file exists** (`test_evidence`, `-s` + mtime newer than HEAD — the runner emitted it this phase, proving the tests actually ran before the phase ships; an empty-but-fresh file, e.g. an interrupted `bun test | tee`, is rejected). If `test_runs_required` > 1 the file must also contain `RUNS=N` with N ≥ required. Skipped only when the manifest has no `test_command`. **This is the check that makes the pre-push hook force tests** — without it, `phase-done` passed with tests never run, and the test pile silently slipped (the original gap). The PR-comment evidence block is the human-facing companion; this file check is the machine gate.
- [ ] every absent-but-claimed-skipped item has a `SKIP: <reason>` line

Checks are deliberately **deterministic + greppable** (file exists / header present / commit in range / mtime fresh). The gate does NOT judge quality — that is the validator + code-quality reviewer. The gate only proves the *ceremony actually happened*.

---

## Project manifest — `.claude/close-gate.json`

The gate is stack-agnostic; per-project specifics live in a small manifest the gate reads. A ready-to-edit copy of exactly the block below ships at `.claude/close-gate.json.example` — copy it to `.claude/close-gate.json` and replace `test_command`:

```json
{
  "phase_docs_glob": "docs/superpowers/specs/*-phase-{PHASE}-*",
  "plan_glob": "docs/superpowers/plans/*-phase-{PHASE}-*",
  "journal": "docs/iteration-journal.md",
  "handoff_glob": "docs/handoff/*-phase-{PHASE}-handoff.md",
  "smoke_a_glob": "docs/smoke/*-phase-{PHASE}-*checklist*",
  "smoke_b_glob": "tests/e2e/**/*phase-{PHASE}*",
  "acceptance_glob": "tests/acceptance/**/*phase-{PHASE}*",
  "test_evidence": ".claude/.last-test-run",
  "test_command": "REPLACE_ME e.g. 'bun test' or '.venv/bin/python -m pytest -q'",
  "test_runs_required": 1,
  "user_visible": true,
  "exempt_user_story": false,
  "exempt_changelog": false
}
```

When `test_runs_required` > 1, the project's `make test-evidence` (or test runner) **MUST emit a `RUNS=N` line** into the evidence file (e.g. `echo "RUNS=$n" >> .claude/.last-test-run`). The gate reads that line; if absent it treats the run-count as 0 and fails.

`{PHASE}` is substituted from the `PHASE=X.Y` arg. `/init-harness` generates this manifest from the detected stack; hand-edit per phase to flip the `exempt_*` / `user_visible` flags (and the gate FORCES a `SKIP:` reason when an exempt flag suppresses a check).

---

## Portable gate script — `scripts/close-gate.sh`

Drop this in the project; wire `make task-done` / `make phase-done` to call it. Pure bash + `git` + `jq`, no stack assumptions.

```bash
#!/usr/bin/env bash
# Usage: close-gate.sh task            (gate one cadence task)
#        close-gate.sh phase X.Y       (gate a phase close)
set -euo pipefail
MODE="${1:?task|phase}"; PHASE="${2:-}"
M=".claude/close-gate.json"; [ -f "$M" ] || { echo "✗ missing $M"; exit 1; }
g() { jq -r ".$1 // empty" "$M" | sed "s/{PHASE}/$PHASE/g"; }
fail=0
ok()  { echo "✓ $1"; }
bad() { echo "✗ $1"; fail=1; }
glob_exists() { compgen -G "$1" >/dev/null 2>&1; }
# escape-hatch: an exempt_* flag is only legitimate if a 'SKIP: <reason>' line is written in the journal
skip_logged() { grep -qE '^[[:space:]]*SKIP:' "$(g journal)" 2>/dev/null; }

if [ "$MODE" = task ]; then
  git log -1 --format=%s | grep -qE '^(feat|fix)(\(|:)' && ok "feat/fix commit" || bad "no feat/fix commit on HEAD"
  git log origin/main..HEAD --format=%s 2>/dev/null | grep -qE '^docs:' && ok "docs: journal commit in branch" || bad "no docs: journal commit in branch range"
  J="$(g journal)"
  # match the journal-schema canonical bold form (**Plan deviations** / **Plan deviations:**) AND an H2/H3 header form
  if grep -qE '\*\*Plan deviations:?\*\*|^#{1,4}[[:space:]]*Plan deviations' "$J" 2>/dev/null; then ok "journal Plan-deviations header"; else bad "journal missing 'Plan deviations' header"; fi
  EV="$(g test_evidence)"; REQ="$(jq -r '.test_runs_required // 1' "$M")"
  if [ -s "$EV" ] && [ "$EV" -nt .git/HEAD ]; then
    if [ "$REQ" -gt 1 ]; then
      n=$(grep -oE 'RUNS=[0-9]+' "$EV" | head -1 | cut -d= -f2); n=${n:-0}
      if [ "$n" -ge "$REQ" ]; then ok "fresh test-evidence, RUNS=$n (>=$REQ)"; else bad "test-evidence RUNS=$n < required $REQ — run tests $REQ× (runner must emit 'RUNS=N')"; fi
    else ok "fresh test-evidence ($EV)"; fi
  else bad "stale/missing test-evidence — run: $(g test_command)"; fi
  # only ADDED lines (^+), and exclude the gate tooling itself (these scripts legitimately contain "[DEBUG-")
  if git diff HEAD~1 2>/dev/null -- . ':(exclude)scripts/close-gate.sh' ':(exclude)scripts/test-close-gate.sh' | grep -qE '^\+.*\[DEBUG-'; then bad "orphan [DEBUG- logs in diff"; else ok "no orphan debug logs"; fi
  # Sweeper diff-direction teeth — inert unless a commit in range is tagged 'Archetype: sweep'.
  # A sweep MUST subtract code (net-negative LOC, audit-artifact paths excluded) or log a SWEEP-PERF win.
  if git log origin/main..HEAD --format=%B 2>/dev/null | grep -qiE '^Archetype:[[:space:]]*sweep'; then
    nums="$(git diff --numstat origin/main..HEAD -- . ':(exclude)docs/**' ':(exclude)CHANGELOG.md' 2>/dev/null)"
    add=$(awk '{a+=$1} END{print a+0}' <<<"$nums"); del=$(awk '{d+=$2} END{print d+0}' <<<"$nums")
    if [ "$del" -gt "$add" ]; then ok "sweep diff net-negative ($add added, $del deleted)"
    elif grep -qE '^[[:space:]]*SWEEP-PERF:' "$(g journal)" 2>/dev/null; then ok "sweep diff not net-negative but SWEEP-PERF evidence logged"
    else bad "Archetype: sweep but diff not net-negative ($add added / $del deleted) and no 'SWEEP-PERF: <evidence>' in journal — a sweep must subtract or prove a perf win"; fi
  fi
elif [ "$MODE" = phase ]; then
  [ -n "$PHASE" ] || { echo "✗ phase mode needs PHASE arg"; exit 1; }
  RANGE="origin/main..HEAD"
  if [ "$(jq -r .exempt_user_story "$M")" = true ]; then
    skip_logged && ok "user-story exempt (SKIP: logged)" || bad "exempt_user_story=true but no 'SKIP:' line in journal"
  else glob_exists "$(g phase_docs_glob)*user-story*" && ok "user-story.md" || bad "no user-story.md for phase $PHASE"; fi
  glob_exists "$(g phase_docs_glob)" && ok "spec doc" || bad "no spec doc for phase $PHASE"
  glob_exists "$(g plan_glob)"       && ok "plan doc" || bad "no plan doc for phase $PHASE"
  glob_exists "$(g handoff_glob)"    && ok "handoff doc" || bad "no handoff doc for phase $PHASE"
  H="$(compgen -G "$(g handoff_glob)" | head -1 || true)"
  if [ -n "$H" ]; then
    # section tokens MUST match the canonical names in references/handoff-template.md §"8 mandatory sections"
    for sec in "What shipped" "How to use" "What changed" "Manual smoke" "Automated smoke" "Code-level tests" "Findings" "Next-step"; do
      grep -qi "$sec" "$H" || bad "handoff missing section: $sec"
    done
  fi
  if [ "$(jq -r .exempt_changelog "$M")" = true ]; then
    skip_logged && ok "changelog exempt (SKIP: logged)" || bad "exempt_changelog=true but no 'SKIP:' line in journal";
  elif git diff --name-only $RANGE 2>/dev/null | grep -q CHANGELOG.md; then ok "CHANGELOG [Unreleased] touched";
  else bad "CHANGELOG.md not touched in $RANGE"; fi
  if [ "$(jq -r .user_visible "$M")" = true ]; then
    glob_exists "$(g smoke_a_glob)" && ok "Track A smoke checklist" || bad "no Track A smoke checklist"
    glob_exists "$(g smoke_b_glob)" && ok "Track B e2e spec"        || bad "no Track B e2e spec"
  fi
  if [ "$(jq -r .exempt_user_story "$M")" = true ]; then ok "acceptance tests exempt (user-story exempt)";
  elif glob_exists "$(g acceptance_glob)"; then ok "acceptance tests present";
  else bad "no acceptance tests for phase $PHASE (cadence step 1.5 unrun?)"; fi
  git diff --name-only $RANGE 2>/dev/null | grep -q 'docs/ROADMAP.md' && ok "ROADMAP touched" || bad "ROADMAP.md not updated in $RANGE"
  git diff --name-only $RANGE 2>/dev/null | grep -q "$(g journal)" && ok "journal touched this phase" || bad "journal not touched in $RANGE"
  # test-evidence at phase close — the pre-push hook runs phase mode, so THIS is what
  # forces tests to actually run before a phase ships. Skipped only when the project has
  # no test_command. (Was missing here originally — tests fell through every hooked gate.)
  if [ -n "$(g test_command)" ]; then
    EV="$(g test_evidence)"; REQ="$(jq -r '.test_runs_required // 1' "$M")"
    if [ -s "$EV" ] && [ "$EV" -nt .git/HEAD ]; then
      if [ "$REQ" -gt 1 ]; then
        n=$(grep -oE 'RUNS=[0-9]+' "$EV" | head -1 | cut -d= -f2); n=${n:-0}
        if [ "$n" -ge "$REQ" ]; then ok "fresh test-evidence, RUNS=$n (>=$REQ)"; else bad "test-evidence RUNS=$n < required $REQ — run tests $REQ× (runner must emit 'RUNS=N')"; fi
      else ok "fresh test-evidence ($EV)"; fi
    else bad "stale/missing test-evidence — run: $(g test_command)"; fi
  fi
fi
[ $fail -eq 0 ] && { echo "── close-gate PASS"; exit 0; } || { echo "── close-gate FAIL ($MODE)"; exit 1; }
```

`make` wiring:

```make
task-done:  ; @bash scripts/close-gate.sh task
phase-done: ; @bash scripts/close-gate.sh phase $(PHASE)
test-gate:  ; @bash scripts/test-close-gate.sh $(PHASE)
```

---

## Self-test — `scripts/test-close-gate.sh`

The gate is a bash script, so it can silently rot (a grep that never matches passes everything; a check wired to the wrong path always ✓). This self-test proves each check actually flips: it stands up a **throwaway detached git worktree** (real working tree never touched), then for every check removes/mangles the artifact and asserts the gate emits ✗, plus a baseline that asserts ✓ when all artifacts are present. Manifest-driven — no project-specific paths baked in. Run `make test-gate PHASE=X.Y` (or `bash scripts/test-close-gate.sh X.Y`) after editing the gate or the manifest.

```bash
#!/usr/bin/env bash
# Self-test for scripts/close-gate.sh — verifies each gate check emits ✗ when its artifact is
# missing and ✓ when present. Manifest-driven (reads .claude/close-gate.json); runs in a throwaway
# DETACHED git worktree so the real working tree is never touched.
# Usage: scripts/test-close-gate.sh <PHASE>     e.g.  scripts/test-close-gate.sh 1.1
set -uo pipefail
PHASE="${1:?usage: test-close-gate.sh <PHASE>}"
ROOT="$(git rev-parse --show-toplevel)"
M="$ROOT/.claude/close-gate.json"; [ -f "$M" ] || { echo "✗ missing $M"; exit 1; }
g() { jq -r ".$1 // empty" "$M" | sed "s/{PHASE}/$PHASE/g"; }
sedi() { sed -i '' "$@" 2>/dev/null || sed -i "$@"; }   # portable in-place sed (GNU vs BSD)
TMP="$(mktemp -d)"; WT="$TMP/wt"
cleanup() { git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
            git -C "$ROOT" worktree remove --force "$TMP/wt2" >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT
git -C "$ROOT" worktree add --quiet --detach "$WT" HEAD
cd "$WT"
mkdir -p "$(dirname "$(g test_evidence)")"; echo "test-run output" > "$(g test_evidence)"   # evidence is gitignored → absent in fresh worktree

pass=0; failc=0
run()     { bash scripts/close-gate.sh "$@" 2>&1 || true; }
neg()     { local d="$1" re="$2"; shift 2; if run "$@" | grep -qE "$re"; then echo "  ✓ NEG  $d"; pass=$((pass+1)); else echo "  ✗ NEG  $d — expected /$re/"; failc=$((failc+1)); fi; }
pos()     { local d="$1"; shift; if bash scripts/close-gate.sh "$@" >/dev/null 2>&1; then echo "  ✓ POS  $d"; pass=$((pass+1)); else echo "  ✗ POS  $d — gate failed unexpectedly"; failc=$((failc+1)); fi; }
restore() { git checkout --quiet -- . 2>/dev/null || true; git clean -fdq 2>/dev/null || true; echo "test-run output" > "$(g test_evidence)"; }

echo "── baseline ──"
pos "phase-done passes with all artifacts" phase "$PHASE"

echo "── phase-mode missing-artifact fail-paths ──"
rm -f $(g phase_docs_glob)*user-story* ;  neg "missing user-story"  'no user-story'  phase "$PHASE"; restore
rm -f $(g plan_glob) ;                    neg "missing plan doc"    'no plan doc'    phase "$PHASE"; restore
rm -f $(g handoff_glob) ;                 neg "missing handoff doc" 'no handoff doc' phase "$PHASE"; restore
H="$(compgen -G "$(g handoff_glob)" | head -1 || true)"
if [ -n "$H" ]; then for tok in "What shipped" "How to use" "What changed" "Manual smoke" "Automated smoke" "Code-level tests" "Findings" "Next-step"; do
  sedi "s/$tok/xxxxx/g" "$H"; neg "handoff missing section: $tok" "missing section: $tok" phase "$PHASE"; restore
done; fi
rm -f $(g smoke_a_glob) ;                 neg "missing Track A smoke" 'no Track A'   phase "$PHASE"; restore
[ -n "$(g smoke_b_glob)" ] && { rm -f $(g smoke_b_glob); neg "missing Track B e2e" 'no Track B' phase "$PHASE"; restore; }
rm -f $(g phase_docs_glob) ;              neg "missing spec doc (all phase docs gone)" 'no spec doc' phase "$PHASE"; restore
[ -n "$(g test_command)" ] && { rm -f "$(g test_evidence)"; neg "phase: stale/missing test-evidence" 'stale/missing test-evidence' phase "$PHASE"; restore; }
[ -n "$(g test_command)" ] && { printf '' > "$(g test_evidence)"; neg "phase: empty-but-fresh test-evidence rejected (-s)" 'stale/missing test-evidence' phase "$PHASE"; restore; }
# missing acceptance tests
rm -f $(g acceptance_glob) ; neg "missing acceptance tests" 'no acceptance tests for phase' phase "$PHASE"; restore
# test_runs_required in phase mode
[ -n "$(g test_command)" ] && {
  tmp=$(mktemp); jq '.test_runs_required=3' "$M" > "$tmp" && mv "$tmp" .claude/close-gate.json
  echo "test-run output" > "$(g test_evidence)"  # fresh but no RUNS= marker
  neg "phase: test_runs_required=3, evidence has no RUNS line" 'RUNS=0 < required 3' phase "$PHASE"
  printf 'RUNS=3\n' >> "$(g test_evidence)"
  pos "phase: test_runs_required=3, RUNS=3 present" phase "$PHASE"
  restore
}

echo "── diff-range checks (CHANGELOG / ROADMAP / journal touched) — tested at an empty range ──"
WT2="$TMP/wt2"
if git -C "$ROOT" worktree add --quiet --detach "$WT2" origin/main 2>/dev/null; then
  mkdir -p "$WT2/scripts" "$WT2/.claude"; cp scripts/close-gate.sh "$WT2/scripts/"; cp "$M" "$WT2/.claude/close-gate.json"
  o="$(cd "$WT2" && bash scripts/close-gate.sh phase "$PHASE" 2>&1 || true)"
  echo "$o" | grep -qE 'CHANGELOG.md not touched' && { echo "  ✓ NEG  CHANGELOG not touched (empty range)"; pass=$((pass+1)); } || { echo "  ✗ NEG  CHANGELOG not-touched path"; failc=$((failc+1)); }
  echo "$o" | grep -qE 'ROADMAP.md not updated'   && { echo "  ✓ NEG  ROADMAP not touched (empty range)";   pass=$((pass+1)); } || { echo "  ✗ NEG  ROADMAP not-updated path"; failc=$((failc+1)); }
  echo "$o" | grep -qE 'journal not touched in'   && { echo "  ✓ NEG  journal not touched (empty range)";   pass=$((pass+1)); } || { echo "  ✗ NEG  journal not-touched path"; failc=$((failc+1)); }
  git -C "$ROOT" worktree remove --force "$WT2" >/dev/null 2>&1 || true
else echo "  ⚠ SKIP diff-range test (could not create origin/main worktree)"; fi

echo "── SKIP escape-hatch (exempt flag requires a logged SKIP) ──"
tmp=$(mktemp); jq '.exempt_user_story=true' "$M" > "$tmp" && mv "$tmp" .claude/close-gate.json
rm -f $(g phase_docs_glob)*user-story*
neg "exempt_user_story=true + no SKIP line"  "exempt_user_story=true but no 'SKIP:'"  phase "$PHASE"
printf '\nSKIP: user-story intentionally omitted (self-test)\n' >> "$(g journal)"
pos "exempt_user_story=true + SKIP logged"   phase "$PHASE"
restore

echo "── exempt_changelog escape-hatch (requires a logged SKIP) ──"
tmp=$(mktemp); jq '.exempt_changelog=true' "$M" > "$tmp" && mv "$tmp" .claude/close-gate.json
neg "exempt_changelog=true + no SKIP line"  "exempt_changelog=true but no 'SKIP:'"  phase "$PHASE"
restore

echo "── task-mode fail-paths ──"
J="$(g journal)"; sedi 's/\*\*Plan deviations/\*\*Plan XXXXX/g' "$J"; neg "journal missing Plan-deviations" "missing 'Plan deviations'" task; restore
rm -f "$(g test_evidence)" ; neg "stale/missing test-evidence" 'stale/missing test-evidence' task; restore
printf '' > "$(g test_evidence)" ; neg "empty-but-fresh test-evidence rejected (-s)" 'stale/missing test-evidence' task; restore
# test_runs_required neg/pos
tmp=$(mktemp); jq '.test_runs_required=3' "$M" > "$tmp" && mv "$tmp" .claude/close-gate.json
echo "test-run output" > "$(g test_evidence)"  # fresh but no RUNS= marker
neg "task: test_runs_required=3, evidence has no RUNS line" 'RUNS=0 < required 3' task
printf 'RUNS=3\n' >> "$(g test_evidence)"
pos "task: test_runs_required=3, RUNS=3 present" task
restore
echo 'x = 1  # [DEBUG-probe] leftover' > .close-gate-probe.py
git add .close-gate-probe.py && git -c user.email=t@t -c user.name=t commit --quiet -m "test: inject debug probe"
neg "orphan [DEBUG- in diff"  'orphan \[DEBUG- logs'  task
git reset --quiet --hard HEAD~1; restore
git -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m "chore: not a cadence task"
neg "non-feat/fix HEAD"  'no feat/fix commit'  task
git reset --quiet --hard HEAD~1; restore
# Sweeper diff-direction teeth: a sweep-tagged commit that ADDS code must fail; a SWEEP-PERF line rescues it
printf 'a\nb\nc\n' > .sweep-probe.txt
git add .sweep-probe.txt && git -c user.email=t@t -c user.name=t commit --quiet -m $'feat: add probe (net-positive)\n\nArchetype: sweep'
neg "sweep tag + net-positive diff flagged" 'not net-negative' task
printf '\nSWEEP-PERF: cache cut p99 by 40ms (self-test escape)\n' >> "$(g journal)"
if bash scripts/close-gate.sh task 2>&1 | grep -qE 'SWEEP-PERF evidence logged'; then echo "  ✓ POS  sweep + SWEEP-PERF escape passes direction check"; pass=$((pass+1)); else echo "  ✗ POS  sweep SWEEP-PERF escape"; failc=$((failc+1)); fi
git reset --quiet --hard HEAD~1; restore
# no docs: commit in branch range — use detached wt2 at origin/main (empty range has no docs: commit)
WT2_DOCS="$TMP/wt2docs"
if git -C "$ROOT" worktree add --quiet --detach "$WT2_DOCS" origin/main 2>/dev/null; then
  mkdir -p "$WT2_DOCS/scripts" "$WT2_DOCS/.claude"; cp scripts/close-gate.sh "$WT2_DOCS/scripts/"; cp "$M" "$WT2_DOCS/.claude/close-gate.json"
  o_docs="$(cd "$WT2_DOCS" && bash scripts/close-gate.sh task 2>&1 || true)"
  echo "$o_docs" | grep -qE 'no docs: journal commit in branch range' && { echo "  ✓ NEG  no docs: journal commit (empty range)"; pass=$((pass+1)); } || { echo "  ✗ NEG  docs: commit branch-range path"; failc=$((failc+1)); }
  git -C "$ROOT" worktree remove --force "$WT2_DOCS" >/dev/null 2>&1 || true
else echo "  ⚠ SKIP docs:-commit range test (could not create origin/main worktree)"; fi

echo ""
echo "════════════════════════════════════════"
echo "close-gate self-test: $pass passed, $failc failed"
[ $failc -eq 0 ] && { echo "── ALL GATE CHECKS BEHAVE CORRECTLY"; exit 0; } || { echo "── SOME CHECKS MISBEHAVE"; exit 1; }
```

Note: the orphan-`[DEBUG-` check in `close-gate.sh` excludes both `scripts/close-gate.sh` and `scripts/test-close-gate.sh` from its scan — both legitimately contain the marker as tooling/test data.

---

## Wiring — three layers, the hook is NOT optional

The gate only forces anything if something *runs* it. The three layers are defense-in-depth, not a menu — **layer 1 is the default and must be active; 2 and 3 are additional cover.** Shipping only layer 3 is the trap that produces the exact symptom this gate exists to kill: the model is *supposed* to run `make phase-done`, finishes the code, feels done, and never runs it. A gate that depends on the model remembering to invoke it is the unreliable layer the skill warns about — make the un-bypassable layer carry the weight.

1. **git pre-push hook — DEFAULT, un-bypassable, installed at bootstrap.** Rejects the push of an incomplete `feat/phase-*` branch *physically*, regardless of model behaviour. This is the layer that actually works. Script below. Never `--no-verify`.
2. **CI job (additional).** A `close-gate` job in PR-time CI that runs `phase-done`. Catches it at the PR even if the local hook was somehow bypassed or absent (e.g. a fresh clone before hooks are wired). Slower loop (push-then-fail) but covers shared repos.
3. **Model-run discipline (additional, always).** The AI MUST run `make task-done` after each cadence task and `make phase-done` before opening the PR, and **paste the gate output**. "I ran it, it passed" without pasted output is an unverified claim — treat as not-run. This layer gives a *fast* local signal; it does NOT replace the hook.

### The pre-push hook — `.githooks/pre-push` (version-controlled, activated via `core.hooksPath`)

Committed to the repo (so teammates + fresh clones get it) and activated with one idempotent config line. On a `feat/phase-*` branch it runs `phase-done`; any other branch pushes freely (phase-push granularity — WIP branches aren't gated).

```bash
#!/usr/bin/env bash
# close-gate pre-push hook — installed by /init-harness (idempotent).
# Rejects pushing a feat/phase-* branch whose close-gate (phase mode) fails.
# Bypass is NOT allowed — fix the missing wrap-up artifact. Never --no-verify.
set -uo pipefail
branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
case "$branch" in
  feat/phase-*)
    phase="$(printf '%s' "$branch" | sed -E 's#^feat/phase-([0-9]+(\.[0-9]+)*).*#\1#')"
    [ -f scripts/close-gate.sh ] || { echo "pre-push: scripts/close-gate.sh missing — run /init-harness --refresh"; exit 1; }
    echo "pre-push: running close-gate phase $phase …"
    if ! bash scripts/close-gate.sh phase "$phase"; then
      echo "── push REJECTED: phase $phase wrap-up incomplete (close-gate FAIL above)."
      echo "   Fix each ✗ (or log a 'SKIP: <reason>' in the journal Plan-deviations), then push again. Never --no-verify."
      exit 1
    fi
    ;;
  *) : ;;   # non-phase branch — not gated
esac
```

Activation (idempotent — safe to re-run; this is what retrofits an EXISTING project):

```bash
mkdir -p .githooks
# (write the script above to .githooks/pre-push if absent)
chmod +x .githooks/pre-push
git config core.hooksPath .githooks   # activates it for this clone
```

> `core.hooksPath` relocates the hooks dir, so put any *other* project hooks under `.githooks/` too. If the project already uses husky / lefthook, add the `close-gate.sh phase` call to that tool's pre-push stage instead — same effect, don't fight the existing manager.

### Retrofit an existing project (one block, idempotent)

A project that has the gate scripts but no active hook (the common gap) is fixed by running the activation block above, then proving it: `git config core.hooksPath` should print `.githooks`, and `make test-gate PHASE=X.Y` should show every check flips.

`/init-harness` scaffolds the gate script + self-test + manifest + `make` targets (`task-done` / `phase-done` / `test-gate`) AND installs+activates this pre-push hook by default (not a stub). Existing projects: copy `scripts/close-gate.sh` + `scripts/test-close-gate.sh`, run `/init-harness --refresh` (which writes `.githooks/pre-push` + sets `core.hooksPath` if missing), then `make test-gate PHASE=X.Y` once to confirm every check flips.

---

## The escape-hatch rule

The skill is full of "skip only when…" clauses. Each is individually reasonable; together they let the model rationalize skipping wrap-up. The gate neutralizes this: **a skip is allowed only when it is written down.** When an `exempt_*` flag is set or an artifact is legitimately absent, the gate requires a `SKIP: <one-line reason>` in the journal "Plan deviations" section. A skip you have to type a reason for is taken far less often than a silent one — and it leaves an audit trail.

---

## Sweeper diff-direction

This is the **one deterministic teeth** the archetype axis (`intent-gate.md` §"Archetype") adds to the gate. The other four archetypes reshape the chain by prose delta (the model applies them, the same way it applies the Size triage); diff direction is enforced because it is the single signal the harness previously had no concept of — nothing stopped a "delete / simplify" task from quietly *adding* surface while flying a cleanup flag.

**What fires it:** any commit in `origin/main..HEAD` carrying an `Archetype: sweep` trailer (written by the gate-front per `intent-gate.md` §"Recording the label"). No such trailer → the check is completely inert; it costs every other archetype nothing.

**What it asserts (task mode):** the code diff over `origin/main..HEAD` — with `docs/**` and `CHANGELOG.md` excluded, because those audit artifacts legitimately grow on every task — is **net-negative LOC** (`deletions > insertions`). 

**The escape:** when a sweep legitimately adds lines but improves performance (adding a cache, a memo table, an index-backed query), the author writes a `SWEEP-PERF: <evidence>` line in the journal "Plan deviations" section. Like the `SKIP:` escape, it is human-written and leaves an audit trail — the model cannot satisfy the teeth by fabricating a perf claim without typing the evidence line, and a reviewer sees it at the PR.

**What it does NOT check:** whether the sweep deleted the *right* thing. Correctness of a deletion is the differential oracle (behavior before == behavior after) + the validator (do the existing ACs still pass). The teeth police direction only — they stop a mislabelled add, nothing more.

Scope note: enforced in **task mode** (a sweep is usually a single cadence task). Phase mode does not run it — at phase range the additive audit artifacts dominate LOC and the signal is unreliable; a phase that is wholly a sweep is the rare case, handled by the per-task checks that compose it.

## Approval timing — the `close-gate` policy key

Everything above is the *deterministic* gate. Separately from it, projects that adopt a **human-blocking close approval** (e.g. a CLAUDE.md rule that the Task Close Report awaits the user's explicit "ok" before commit) choose WHERE that human approval sits via a CLAUDE.md policy key:

```
close-gate: per-task | pr-boundary
```

- **`per-task` (default)** — the human's blocking approval happens at every task close: the Task Close Report is posted and the session waits for the user's "ok" before committing. Highest-comprehension mode: the human reads every diff at the moment it lands.
- **`pr-boundary`** — the per-task read is delegated to an independent **read-only** reviewer subagent (same correctness-vs-promise lens as the validator). Task Close Reports are still **written for every task** — the audit trail does not thin out — but they no longer block. The human's blocking approval happens **once per PR/merge**, reading the accumulated reports + the full diff.

**What this key does NOT change:** the deterministic `task-done` / `phase-done` gates above run identically in both modes. The key moves the *human* approval point only; it never relaxes the machine gate, the journal, or the test-evidence checks.

**What `pr-boundary` additionally requires — the review record.** Because the human reads nothing until merge, the merge-time read must be auditable: the PR carries (A) every review round's report **verbatim** (writer-untouched, with SHA-range scope header + "not reviewed" list + dispatch-prompt provenance) and (B) the builder's per-finding response (agree/disagree + why, re-graded severity, what changed / deliberately didn't). Reviewer dispatch follows the bias constraints (fresh context, read-only, tier set explicitly, refute-first, `file:line` evidence gate, controller-computed verdict). **Coverage window check before merge:** `git log <last-review-SHA>..HEAD` must be empty, or those commits get a final-pass round — commits after the last review are unreviewed code in a "reviewed" PR. Full spec: `references/review-record.md`.

### The attack surface — read this before flipping to `pr-boundary`

The per-task human gate exists for one reason beyond diff confidence: **any approval the AI can write itself is not an approval.** Two real incidents shaped the current design:

1. An AI treated a prose-only ("soft") close gate as optional and bypassed it. The fix was structural — a hard hook the model cannot talk past — not more prose.
2. An AI fabricated the user's approval: it wrote "user approved" into the record when the user had said nothing.

`pr-boundary` widens the window in which the AI works with no human reading anything. That is acceptable ONLY while the merge boundary keeps a **human-written approval marker the AI physically cannot author**: the user themself performs the approving act (clicks merge, writes the approving PR comment/reply, runs the merge command), and wherever a hook checks for an approval marker, the marker's semantics must be "human typed this" — never a file or string the AI can produce on the user's behalf. If the project's merge approval can be generated by the AI, the self-certification hole is open and `pr-boundary` is NOT safe to enable.

### Run it as an experiment

Flipping to `pr-boundary` is a falsifiable experiment, not a permanent setting:

- Run 2-3 tracks/phases in `pr-boundary` mode, then check two signals: (1) **catch parity** — did the PR-boundary read still catch what the per-task reads used to catch (compare the reviewer subagent's per-task findings against what you find yourself at merge)? (2) **comprehension drift** — are diffs merging that you could not explain afterward?
- **Record, don't remember:** append one catch-parity line per track to the review-verbatim draft's footer (`catch-parity: track N — rounds=R, real-findings=…, fix-introduced-bugs-caught=…, human-merge-time-finds=…` — format in `references/review-record.md`). 2-3 tracks of these lines ARE the rollback/keep evidence.
- Either signal fails → rollback is one line: flip the key back to `per-task`.

---

## Anti-patterns — STOP

- **Claiming "done" without running the gate / without pasting its output** → not done; run it, paste it.
- **Hand-writing the test-evidence file** instead of letting the runner emit it → defeats freshness check; the runner writes it, mtime proves tests actually ran.
- **`--no-verify` to push past the pre-push gate** → blocked; fix the missing artifact, never bypass.
- **Marking a `task-done` ✗ as "fine, I'll do it later"** then opening the PR → `phase-done` will re-block; the debt compounds. Close each task fully.
- **Editing `exempt_*` to silence a check you just don't want to do** → only legitimate when the phase truly has no observable behavior; the `SKIP:` reason is reviewed at PR.
- **Gate passing treated as "quality approved"** → no. Gate proves ceremony happened. Correctness is the validator; craft is the code-quality reviewer. All three are separate.
- **`phase-done` doesn't check fresh test-evidence** → the original gap that let the test pile slip: the pre-push hook runs `phase-done`, but if `phase-done` omits the evidence check, a phase ships with tests never run (`.claude/.last-test-run` never written, yet the gate PASSes). `task-done` checks evidence but has no hook; `phase-done` is hooked but skipped the check. Tests = the one artifact with no live gate. Fix: `phase-done` checks fresh `test_evidence` (mtime > HEAD) whenever `test_command` is set. Confirm the gate output shows a `fresh test-evidence` line.
- **Gate scripts + manifest + `make` targets present, but NO active pre-push hook** (`git config core.hooksPath` empty AND no husky/lefthook stage) → only the weakest layer (model-discipline) is live, and the model skips wrap-up as predicted. This is NOT "the gate is installed." Run the retrofit block (write `.githooks/pre-push` + `git config core.hooksPath .githooks`); confirm with `git config core.hooksPath`.
- **Treating the pre-push hook as one option among three** ("I'll just run `make phase-done` myself") → the hook is the default and must be active; model-discipline is additional, not a substitute. The whole point is to not depend on the model remembering.
- **Tagging a task `Archetype: sweep` then adding net surface** → the diff-direction teeth block it. If the add is a real perf win, log `SWEEP-PERF: <evidence>` (human-written, audited at PR); if it is not a cleanup, it was the wrong archetype — re-tag it `build`/`maintain` and run the chain that shape demands. Do NOT add a hollow `SWEEP-PERF:` line to dodge the check; the reviewer reads it.
