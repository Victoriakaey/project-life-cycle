#!/usr/bin/env bash
# install-close-gate-hook.sh — chain the wrap-up close-gate into the LOCAL pre-push hook,
# WITHOUT disturbing whatever that hook already does.
#
# Why a local chain and not core.hooksPath=.githooks:
# This repo's push protection (.git/hooks/pre-push) is an EXISTING LOCAL HOOK — deliberately
# untracked, "lives only on this machine" (its own header says so). git honours exactly ONE
# hooks dir, so setting core.hooksPath=.githooks would SILENTLY DISABLE that hook. Instead
# we append a one-line call to scripts/close-gate-prepush.sh into the existing local hook: the
# existing hook keeps running as git's native pre-push, and the wrap-up gate runs right after it.
# Both gate scripts (close-gate.sh + close-gate-prepush.sh) are tracked + reviewable; only the
# one-line WIRING is local — the same local-only shape that hook already has. This installer
# is the tracked, idempotent, reviewable record of that wiring.
#
# Run once per clone:  bash scripts/install-close-gate-hook.sh
set -euo pipefail

HOOK=".git/hooks/pre-push"
MARK="# >>> close-gate wrap-up chain (scripts/install-close-gate-hook.sh) >>>"

[ -d .git ] || { echo "✗ not a git repo root"; exit 1; }

if [ -f "$HOOK" ] && grep -qF "$MARK" "$HOOK"; then
  echo "✓ close-gate chain already installed in $HOOK — nothing to do"
  exit 0
fi

# The three lines to inject. Kept trivial on purpose — all real logic lives in the tracked
# scripts/close-gate-prepush.sh, so there is no bash-in-a-string to escape here.
L1="$MARK"
L2='if [ -x scripts/close-gate-prepush.sh ]; then scripts/close-gate-prepush.sh || exit 1; fi'
L3="# <<< close-gate wrap-up chain <<<"

if [ ! -f "$HOOK" ]; then
  # No local pre-push hook present (fresh clone) — create a minimal hook that just runs the chain.
  printf '#!/bin/bash\nset -u\n\n%s\n%s\n%s\n\nexit 0\n' "$L1" "$L2" "$L3" > "$HOOK"
  chmod +x "$HOOK"
  echo "✓ created $HOOK with the close-gate chain (no pre-existing pre-push hook found)"
  exit 0
fi

# A local hook exists — insert the 3 lines just BEFORE its final `exit 0` (so they run after all the
# leak checks but are still reached). Match an indented and/or trailing-comment form too, not just
# a bare `exit 0` — otherwise a hook whose final exit is written `  exit 0` or `exit 0  # done`
# would be mis-detected as "no exit 0", and the chain would be appended AFTER the already-run exit
# (dead code) while still printing success. `tail -1` targets the LAST such line (the final exit).
EXITRE='^[[:space:]]*exit[[:space:]]+0([[:space:]]*#.*)?$'
if grep -qE "$EXITRE" "$HOOK"; then
  last="$(grep -nE "$EXITRE" "$HOOK" | tail -1 | cut -d: -f1)"
  tmp="$(mktemp)"
  awk -v n="$last" -v l1="$L1" -v l2="$L2" -v l3="$L3" \
    'NR==n{print ""; print l1; print l2; print l3; print ""} {print}' "$HOOK" > "$tmp"
  mv "$tmp" "$HOOK"
else
  printf '\n%s\n%s\n%s\nexit 0\n' "$L1" "$L2" "$L3" >> "$HOOK"
fi
chmod +x "$HOOK"
echo "✓ chained close-gate into existing $HOOK (existing hook preserved, runs first)"
