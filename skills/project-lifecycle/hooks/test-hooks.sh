#!/usr/bin/env bash
# Deterministic tests for the project-lifecycle frontmatter hook scripts.
# Run before sync. No fresh session needed — these exercise the scripts directly.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

ev(){ printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

echo "=== guard.sh ==="
ev 'git commit --no-verify -m x' | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 2 ] && ok "blocks --no-verify" || no "blocks --no-verify"
ev 'git push origin main'        | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 2 ] && ok "blocks push origin main" || no "blocks push origin main"
ev 'git push origin HEAD:main'   | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 2 ] && ok "blocks push HEAD:main" || no "blocks push HEAD:main"
ev 'git push origin feat/phase-1.2-x' | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows push to feat branch" || no "allows push to feat branch"
ev 'git push origin main-experiment'  | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows push to main-experiment (no false positive)" || no "allows main-experiment"
ev 'echo hello'                  | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows ordinary command" || no "allows ordinary command"
ev 'npm run verify'              | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows 'verify' substring (no --no-verify false positive)" || no "allows verify substring"

echo "=== close-gate-nudge.sh ==="
# On this repo (branch main, not feat/phase-*) → must be silent.
OUT="$(echo '{}' | bash "$HERE/close-gate-nudge.sh" Stop 2>/dev/null)"
[ -z "$OUT" ] && ok "silent off a phase branch" || no "silent off a phase branch (got: $OUT)"

# Integration: temp git repo on a feat/phase-* branch + dirty → must emit JSON.
TMP="$(mktemp -d)"
(
  cd "$TMP"
  git init -q && git config user.email t@t && git config user.name t
  echo a > a.txt && git add a.txt && git commit -qm init
  git checkout -q -b feat/phase-1.0-test
  echo b > b.txt   # uncommitted → dirty
  rm -rf .claude
  OUT="$(echo '{}' | bash "$HERE/close-gate-nudge.sh" Stop 2>/dev/null)"
  echo "$OUT" | python3 -c 'import json,sys
d=json.load(sys.stdin)
a=d["hookSpecificOutput"]["additionalContext"]
assert d["hookSpecificOutput"]["hookEventName"]=="Stop"
assert "Definition of Done" in a and "feat/phase-1.0-test" in a
print("  PASS: emits nudge JSON on dirty phase branch")' || echo "  FAIL: emits nudge JSON on dirty phase branch (got: $OUT)"
  # Throttle: second call within 10 min → silent.
  OUT2="$(echo '{}' | bash "$HERE/close-gate-nudge.sh" Stop 2>/dev/null)"
  [ -z "$OUT2" ] && echo "  PASS: throttled (silent within 10 min)" || echo "  FAIL: throttle (got: $OUT2)"
)
rm -rf "$TMP"

echo
echo "=== frontmatter YAML parses ==="
python3 - "$HERE/.." <<'PY'
import yaml, sys
raw=open(sys.argv[1] + "/SKILL.md").read()
d=yaml.safe_load(raw.split("---",2)[1])
h=d.get("hooks",{})
assert "PreToolUse" in h and "Stop" in h and "SubagentStop" in h, "missing hook events: %s"%list(h)
assert h["PreToolUse"][0]["hooks"][0]["command"]=="./hooks/guard.sh"
print("  PASS: SKILL.md frontmatter hooks block valid")
PY

echo
echo "RESULT: $PASS passed, $FAIL failed (note: temp-repo sub-results print inline above)"
[ "$FAIL" -eq 0 ] || exit 1
