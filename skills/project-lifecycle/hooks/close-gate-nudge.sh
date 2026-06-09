#!/usr/bin/env bash
# project-lifecycle — Stop / SubagentStop close-gate nudge.
# Injects a one-line close-gate reminder via hookSpecificOutput.additionalContext,
# but ONLY when it is actually relevant and not too often:
#   - on a feat/phase-* branch (we are mid-phase), AND
#   - there are uncommitted changes OR no fresh test-evidence, AND
#   - we have not already nudged in the last 10 minutes (throttle).
# Silent in every other case. Always exits 0 — never blocks turn/subagent end.
# Realizes the skill's "Definition of Done" forcing function as a platform nudge.
set -euo pipefail

EVENT="${1:-Stop}"
cat >/dev/null 2>&1 || true   # drain the hook event JSON on stdin; we don't need it

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
case "$BRANCH" in
  feat/phase-*) ;;
  *) exit 0 ;;            # not mid-phase → nothing to nudge about
esac

REASON=""
[ -n "$(git status --porcelain 2>/dev/null || true)" ] && REASON="uncommitted changes"
if [ ! -f .claude/.last-test-run ]; then
  REASON="${REASON:+$REASON; }no fresh test-evidence (.claude/.last-test-run missing)"
fi
[ -z "$REASON" ] && exit 0   # clean + tested → silent

# Throttle: at most one nudge per 10 minutes, so a long phase isn't spammed.
THROTTLE=".claude/.close-gate-nudge-last"
NOW="$(date +%s)"
LAST=0
[ -f "$THROTTLE" ] && LAST="$(cat "$THROTTLE" 2>/dev/null || echo 0)"
if [ $((NOW - LAST)) -lt 600 ]; then exit 0; fi
mkdir -p .claude 2>/dev/null || true
echo "$NOW" > "$THROTTLE" 2>/dev/null || true

MSG="[project-lifecycle] On ${BRANCH} with ${REASON}. Before claiming done: run make task-done / phase-done and paste its output; confirm every wrap-up todo (journal / tests-3x / handoff / CHANGELOG / smoke / PR-comment) is checked or logged as SKIP. (SKILL.md \"Definition of Done\")"

python3 - "$EVENT" "$MSG" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": sys.argv[1], "additionalContext": sys.argv[2]}}))
PY
exit 0
