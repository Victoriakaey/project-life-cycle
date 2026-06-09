#!/usr/bin/env bash
# project-lifecycle — PreToolUse:Bash guard.
# Enforces, deterministically, two rules the skill states in prose (SKILL.md
# §"Commits & branching"): never `--no-verify`, never push directly to main.
# Travels WITH the skill (frontmatter hook), complementing the per-project git
# pre-push hook. Conservative, high-confidence patterns only — exit 2 blocks the
# tool call, exit 0 allows. False positives are worse than a missed catch here,
# so we only block what is unambiguous.
set -euo pipefail

INPUT="$(cat 2>/dev/null || true)"
CMD="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null || true)"

[ -z "$CMD" ] && exit 0

# Rule 1 — --no-verify is forbidden (fix the hook complaint, never bypass it).
if printf '%s' "$CMD" | grep -Eq -- '(^|[[:space:]])--no-verify([[:space:]]|$)'; then
  echo "[project-lifecycle] Blocked: --no-verify is forbidden — fix the failing hook/linter, do not bypass it. (SKILL.md §Commits & branching)" >&2
  exit 2
fi

# Rule 2 — never push directly to main. Block only when 'main' appears as an
# explicit whole-token ref in a git push (e.g. `git push origin main`,
# `git push origin HEAD:main`). Other-branch pushes are allowed untouched.
if printf '%s' "$CMD" | grep -Eq 'git[[:space:]]+push' \
   && printf '%s' "$CMD" | grep -Eq '(:|[[:space:]])main([[:space:]]|:|$)'; then
  echo "[project-lifecycle] Blocked: never push directly to main — open a feat/phase-* branch and a PR. (SKILL.md §Commits & branching)" >&2
  exit 2
fi

exit 0
