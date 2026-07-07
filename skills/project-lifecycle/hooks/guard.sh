#!/usr/bin/env bash
# project-lifecycle — PreToolUse:Bash guard.
# Enforces two rules the skill states in prose (SKILL.md "Commits & branching"):
# never the no-verify bypass flag, never push directly to main. Travels WITH the
# skill (frontmatter hook), complementing the per-project git pre-push hook.
#
# Detection tokenizes the command with shlex and matches REAL argv tokens, not
# substrings — so a commit MESSAGE that merely mentions the flag or the word
# "main" (e.g. git commit -m "docs about --no-verify") is NOT a false positive.
# Exit 2 blocks the tool call; exit 0 allows. Fails OPEN (exit 0) on unparseable
# input so a weird-but-legitimate command is never wrongly blocked — the git
# pre-push hook remains the un-bypassable backstop.
set -euo pipefail
INPUT="$(cat 2>/dev/null || true)"
python3 - "$INPUT" <<'PY'
import json, sys, shlex
try:
    cmd = json.loads(sys.argv[1]).get("tool_input", {}).get("command", "")
except Exception:
    sys.exit(0)
if not cmd:
    sys.exit(0)
try:
    toks = shlex.split(cmd)
except Exception:
    sys.exit(0)  # unparseable -> don't false-block; pre-push hook is the real gate

# Rule 1 -- the no-verify bypass flag as an actual argv token (fix the failing
# hook/linter, never bypass it).
if "--no-verify" in toks:
    sys.stderr.write("[project-lifecycle] Blocked: --no-verify is forbidden -- fix the failing hook/linter, do not bypass it. (SKILL.md §Commits & branching)\n")
    sys.exit(2)

# Rule 2 -- never push directly to main (main as a real ref token: `main` or `...:main`).
if "push" in toks and any(t == "main" or t.endswith(":main") for t in toks):
    sys.stderr.write("[project-lifecycle] Blocked: never push directly to main -- open a feat/phase-* branch and a PR. (SKILL.md §Commits & branching)\n")
    sys.exit(2)

sys.exit(0)
PY
