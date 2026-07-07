#!/usr/bin/env bash
# Deterministic tests for the project-lifecycle frontmatter hook scripts.
# Run before committing hook changes. No fresh session needed — these exercise the scripts directly.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

# Build the hook event JSON via json.dumps so commands containing quotes
# (e.g. a -m "message") are escaped correctly.
ev(){ python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }

echo "=== guard.sh ==="
ev 'git commit --no-verify -m x' | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 2 ] && ok "blocks --no-verify flag" || no "blocks --no-verify flag"
ev 'git push origin main'        | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 2 ] && ok "blocks push origin main" || no "blocks push origin main"
ev 'git push origin HEAD:main'   | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 2 ] && ok "blocks push HEAD:main" || no "blocks push HEAD:main"
ev 'git push origin feat/phase-1.2-x' | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows push to feat branch" || no "allows push to feat branch"
ev 'git push origin main-experiment'  | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows push to main-experiment (no false positive)" || no "allows main-experiment"
ev 'echo hello'                  | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows ordinary command" || no "allows ordinary command"
ev 'npm run verify'              | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows 'verify' substring" || no "allows verify substring"
# Regression: the flag/word appearing inside a commit MESSAGE must NOT false-block (shlex fix).
ev 'git commit -m "docs: guard blocks the --no-verify bypass"' | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows --no-verify inside a commit message (shlex)" || no "false-positive: --no-verify in message"
ev 'git commit -m "note: push to main later"' | bash "$HERE/guard.sh" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows 'main' inside a commit message (shlex)" || no "false-positive: main in message"

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
if python3 - "$HERE/.." <<'PY'
import yaml, sys
raw=open(sys.argv[1] + "/SKILL.md").read()
d=yaml.safe_load(raw.split("---",2)[1])
h=d.get("hooks",{})
assert "PreToolUse" in h and "Stop" in h and "SubagentStop" in h, "missing hook events: %s"%list(h)
root="${QODER_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/project-lifecycle/hooks/"
cmds={
  "PreToolUse": h["PreToolUse"][0]["hooks"][0]["command"],
  "Stop": h["Stop"][0]["hooks"][0]["command"],
  "SubagentStop": h["SubagentStop"][0]["hooks"][0]["command"],
}
assert cmds["PreToolUse"]==root+"guard.sh", cmds["PreToolUse"]
assert cmds["Stop"]==root+"close-gate-nudge.sh Stop", cmds["Stop"]
assert cmds["SubagentStop"]==root+"close-gate-nudge.sh SubagentStop", cmds["SubagentStop"]
PY
then ok "SKILL.md frontmatter hooks block valid (all 3 commands)"; else no "SKILL.md frontmatter hooks block valid (all 3 commands)"; fi

echo
echo "=== context-floor.sh (enforce-only, self-arming) ==="
CFTMP="$(mktemp -d)"
(
  export TMPDIR="$CFTMP"
  # hermetic: don't inherit a caller's floor config (e.g. settings.json env block)
  unset PLC_CONTEXT_FLOOR PLC_CONTEXT_FLOOR_PCT PLC_CONTEXT_FLOOR_STEP PLC_CONTEXT_WINDOW
  mktrans(){ python3 -c 'import json,sys; open(sys.argv[1],"w").write(json.dumps({"type":"assistant","message":{"usage":{"input_tokens":int(sys.argv[2]),"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}})+"\n")' "$1" "$2"; }
  evc(){ python3 -c 'import json,sys; print(json.dumps({"session_id":sys.argv[2],"transcript_path":sys.argv[1],"cwd":sys.argv[3]}))' "$1" "$2" "$3"; }
  cf(){ bash "$HERE/context-floor.sh"; }   # reads stdin; PreToolUse:Edit|Write
  M="$CFTMP/plc-context-floor"

  # under floor -> allow, no marker
  T="$CFTMP/below.jsonl"; mktrans "$T" 120000
  evc "$T" b "$CFTMP" | cf >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/b.marker" ]; } && echo "  PASS: allows under floor" || echo "  FAIL: allows under floor"

  # over floor, no RESUME -> self-arm + block (exit 2)
  T="$CFTMP/over.jsonl"; mktrans "$T" 160000
  evc "$T" a "$CFTMP" | cf >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 2 ] && [ -f "$M/a.marker" ]; } && echo "  PASS: self-arms + blocks over floor (no RESUME)" || echo "  FAIL: self-arms + blocks over floor"

  # still blocked while RESUME stale (older than marker)
  echo stale > "$CFTMP/RESUME.md"; sleep 1; touch "$M/a.marker"   # bump marker newer than RESUME
  evc "$T" a "$CFTMP" | cf >/dev/null 2>&1; [ $? -eq 2 ] && echo "  PASS: stays blocked while RESUME stale" || echo "  FAIL: stays blocked while RESUME stale"

  # fresh RESUME -> clear marker + write clearedat + allow
  sleep 1; echo fresh > "$CFTMP/RESUME.md"
  evc "$T" a "$CFTMP" | cf >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/a.marker" ] && [ -f "$M/a.clearedat" ]; } && echo "  PASS: clears on fresh RESUME" || echo "  FAIL: clears on fresh RESUME"

  # post-clear grace: occ < clearedat+step -> allow, no re-arm
  CA="$(cat "$M/a.clearedat")"
  T="$CFTMP/grace.jsonl"; mktrans "$T" $((CA + 10000))
  evc "$T" a "$CFTMP" | cf >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/a.marker" ]; } && echo "  PASS: post-clear grace allows (<clearedat+step)" || echo "  FAIL: post-clear grace allows"

  # past grace: occ >= clearedat+step -> re-arm + block
  T="$CFTMP/regrow.jsonl"; mktrans "$T" $((CA + 35000))
  evc "$T" a "$CFTMP" | cf >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 2 ] && [ -f "$M/a.marker" ]; } && echo "  PASS: re-arms + blocks past grace step" || echo "  FAIL: re-arms past grace step"

  # escape hatch: PLC_CONTEXT_FLOOR=0 -> allow even far over floor
  T="$CFTMP/dis.jsonl"; mktrans "$T" 500000
  evc "$T" dis "$CFTMP" | PLC_CONTEXT_FLOOR=0 bash "$HERE/context-floor.sh" >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/dis.marker" ]; } && echo "  PASS: PLC_CONTEXT_FLOOR=0 disables" || echo "  FAIL: PLC_CONTEXT_FLOOR=0 disables"

  # custom floor 80k -> blocks at 90k
  T="$CFTMP/c.jsonl"; mktrans "$T" 90000
  evc "$T" c "$CFTMP" | PLC_CONTEXT_FLOOR=80000 bash "$HERE/context-floor.sh" >/dev/null 2>&1; [ $? -eq 2 ] && echo "  PASS: custom PLC_CONTEXT_FLOOR honored" || echo "  FAIL: custom PLC_CONTEXT_FLOOR honored"

  # window-% mode: 70% of 1M = 700K floor -> 650K allows (under), 720K blocks (over)
  T="$CFTMP/pctlo.jsonl"; mktrans "$T" 650000
  evc "$T" pctlo "$CFTMP" | PLC_CONTEXT_FLOOR_PCT=70 PLC_CONTEXT_WINDOW=1000000 bash "$HERE/context-floor.sh" >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/pctlo.marker" ]; } && echo "  PASS: window-% mode allows under %-floor" || echo "  FAIL: window-% mode allows under %-floor"
  T="$CFTMP/pcthi.jsonl"; mktrans "$T" 720000
  evc "$T" pcthi "$CFTMP" | PLC_CONTEXT_FLOOR_PCT=70 PLC_CONTEXT_WINDOW=1000000 bash "$HERE/context-floor.sh" >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 2 ] && [ -f "$M/pcthi.marker" ]; } && echo "  PASS: window-% mode blocks over %-floor" || echo "  FAIL: window-% mode blocks over %-floor"

  # window-% overrides absolute: 720K under 70% of 1M allows even though >150K abs default
  T="$CFTMP/pctov.jsonl"; mktrans "$T" 680000
  evc "$T" pctov "$CFTMP" | PLC_CONTEXT_FLOOR_PCT=70 PLC_CONTEXT_WINDOW=1000000 PLC_CONTEXT_FLOOR=150000 bash "$HERE/context-floor.sh" >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/pctov.marker" ]; } && echo "  PASS: window-% overrides absolute floor" || echo "  FAIL: window-% overrides absolute floor"

  # disable: PLC_CONTEXT_FLOOR=0 AND PLC_CONTEXT_FLOOR_PCT=0 -> allow far over
  T="$CFTMP/pctdis.jsonl"; mktrans "$T" 800000
  evc "$T" pctdis "$CFTMP" | PLC_CONTEXT_FLOOR=0 PLC_CONTEXT_FLOOR_PCT=0 bash "$HERE/context-floor.sh" >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/pctdis.marker" ]; } && echo "  PASS: both-zero disables" || echo "  FAIL: both-zero disables"

  # fail-open: malformed transcript -> allow
  echo "{ not json" > "$CFTMP/bad.jsonl"
  evc "$CFTMP/bad.jsonl" badc "$CFTMP" | cf >/dev/null 2>&1; [ $? -eq 0 ] && echo "  PASS: fail-open on malformed transcript" || echo "  FAIL: fail-open on malformed transcript"

  # fail-open: missing usage field -> allow
  python3 -c 'open("'"$CFTMP"'/nousage.jsonl","w").write("{\"type\":\"assistant\",\"message\":{}}\n")'
  evc "$CFTMP/nousage.jsonl" nu "$CFTMP" | cf >/dev/null 2>&1; [ $? -eq 0 ] && echo "  PASS: fail-open on missing usage" || echo "  FAIL: fail-open on missing usage"

  # RESUME exemption: editing the checkpoint file itself is never blocked (no deadlock)
  evf(){ python3 -c 'import json,sys; print(json.dumps({"session_id":sys.argv[2],"transcript_path":sys.argv[1],"cwd":sys.argv[3],"tool_input":{"file_path":sys.argv[4]}}))' "$1" "$2" "$3" "$4"; }
  T="$CFTMP/exempt.jsonl"; mktrans "$T" 300000   # far over floor
  evf "$T" ex "$CFTMP" "$CFTMP/RESUME.md" | cf >/dev/null 2>&1; RC=$?
  { [ "$RC" -eq 0 ] && [ ! -f "$M/ex.marker" ]; } && echo "  PASS: RESUME.md write exempt from block (no deadlock)" || echo "  FAIL: RESUME.md write exempt"
)
rm -rf "$CFTMP"

echo
echo "RESULT: $PASS passed, $FAIL failed (note: temp-repo sub-results print inline above)"
[ "$FAIL" -eq 0 ] || exit 1
