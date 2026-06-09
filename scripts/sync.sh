#!/usr/bin/env bash
# sync.sh — sync the live skill at ~/.claude/skills/project-lifecycle/
# AND curated slash commands from ~/.claude/commands/ into this repo
# (or vice versa), then optionally commit + push.
#
# Two artifacts are mirrored:
#
#   Skill:    ~/.claude/skills/project-lifecycle/  ↔  repo's skills/project-lifecycle/
#             (whole-dir mirror via rsync --delete)
#
#   Commands: per-file mirror governed by scripts/commands-manifest.txt
#             (one filename per line; only listed files are synced — we do NOT
#             mirror the whole ~/.claude/commands/ dir because it contains a
#             lot of user-local commands that should not ship).
#
# Two directions:
#
#   push    Copy live  →  repo (default — you edited live and want to publish)
#   pull    Copy repo  →  live (you pulled new commits and want them live)
#   check   Diff both directions, no writes. Exit non-zero if drift.
#
# Usage:
#   ./scripts/sync.sh                 # push (live → repo), no commit
#   ./scripts/sync.sh push --commit   # push + git add + git commit + git push
#   ./scripts/sync.sh pull            # pull (repo → live)
#   ./scripts/sync.sh check           # diff only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE_SKILL="${HOME}/.claude/skills/project-lifecycle"
REPO_SKILL="${REPO_ROOT}/skills/project-lifecycle"
LIVE_COMMANDS="${HOME}/.claude/commands"
REPO_COMMANDS="${REPO_ROOT}/commands"
MANIFEST="${REPO_ROOT}/scripts/commands-manifest.txt"

DIRECTION="${1:-push}"
COMMIT=false
for arg in "${@:2}"; do
  case "$arg" in
    --commit) COMMIT=true ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

require_skill_dirs() {
  if [ ! -d "$LIVE_SKILL" ]; then
    echo "live skill dir missing: $LIVE_SKILL" >&2
    echo "  (create it first by installing this skill or copying from repo)" >&2
    exit 1
  fi
  if [ ! -d "$REPO_SKILL" ]; then
    echo "repo skill dir missing: $REPO_SKILL" >&2
    exit 1
  fi
}

require_commands_dirs() {
  if [ ! -d "$LIVE_COMMANDS" ]; then
    mkdir -p "$LIVE_COMMANDS"
  fi
  if [ ! -d "$REPO_COMMANDS" ]; then
    mkdir -p "$REPO_COMMANDS"
  fi
  if [ ! -f "$MANIFEST" ]; then
    echo "manifest missing: $MANIFEST" >&2
    exit 1
  fi
}

# Read the manifest into a global array, stripping comments + blanks.
read_manifest() {
  COMMAND_FILES=()
  while IFS= read -r line; do
    line="${line%%#*}"             # strip trailing comments
    line="${line//[[:space:]]/}"   # strip whitespace
    [ -z "$line" ] && continue
    COMMAND_FILES+=("$line")
  done < "$MANIFEST"
}

do_check() {
  require_skill_dirs
  require_commands_dirs
  read_manifest
  local drift=0

  echo "==> check skill: live ↔ repo"
  if diff -r "$LIVE_SKILL" "$REPO_SKILL" > /dev/null 2>&1; then
    echo "  skill in sync"
  else
    diff -r "$LIVE_SKILL" "$REPO_SKILL" || true
    drift=1
  fi

  echo "==> check commands: live ↔ repo (per manifest)"
  for cmd in "${COMMAND_FILES[@]}"; do
    local live="$LIVE_COMMANDS/$cmd"
    local repo="$REPO_COMMANDS/$cmd"
    if [ ! -f "$live" ] && [ ! -f "$repo" ]; then
      echo "  MISSING BOTH: $cmd"
      drift=1
      continue
    fi
    if [ ! -f "$live" ]; then
      echo "  ONLY IN REPO: $cmd"
      drift=1
      continue
    fi
    if [ ! -f "$repo" ]; then
      echo "  ONLY LIVE: $cmd"
      drift=1
      continue
    fi
    if ! diff -q "$live" "$repo" > /dev/null 2>&1; then
      echo "  DIFFERS: $cmd"
      diff "$live" "$repo" || true
      drift=1
    fi
  done

  if [ "$drift" -eq 0 ]; then
    echo "in sync"
    return 0
  fi
  echo ""
  echo "DRIFT detected — run './scripts/sync.sh push' or 'pull' to resolve."
  return 1
}

do_push() {
  require_skill_dirs
  require_commands_dirs
  read_manifest

  echo "==> push skill: live ($LIVE_SKILL) → repo ($REPO_SKILL)"
  rsync -a --delete \
    --exclude '.DS_Store' \
    --exclude '*.swp' \
    "$LIVE_SKILL/" "$REPO_SKILL/"

  echo "==> push commands (per manifest): live → repo"
  for cmd in "${COMMAND_FILES[@]}"; do
    local live="$LIVE_COMMANDS/$cmd"
    if [ ! -f "$live" ]; then
      echo "  WARN: manifest lists '$cmd' but live file missing: $live" >&2
      continue
    fi
    cp "$live" "$REPO_COMMANDS/$cmd"
    echo "  pushed: $cmd"
  done

  echo "==> validate"
  python3 "$REPO_ROOT/scripts/validate.py"

  echo "==> diff (vs git HEAD)"
  cd "$REPO_ROOT"
  git status --short skills/ commands/

  if [ "$COMMIT" = true ]; then
    if git diff --quiet skills/ commands/ && [ -z "$(git status --porcelain skills/ commands/)" ]; then
      echo "no changes to commit"
      return 0
    fi
    git add skills/ commands/
    echo "==> commit + push"
    git commit -m "sync: update skill + commands from live ($(date +%Y-%m-%d))"
    git push
  else
    echo ""
    echo "Push complete. Review with 'git diff skills/ commands/'. To commit:"
    echo "  ./scripts/sync.sh push --commit"
  fi
}

do_pull() {
  require_skill_dirs
  require_commands_dirs
  read_manifest

  echo "==> pull skill: repo ($REPO_SKILL) → live ($LIVE_SKILL)"
  rsync -a --delete \
    --exclude '.DS_Store' \
    --exclude '*.swp' \
    "$REPO_SKILL/" "$LIVE_SKILL/"

  echo "==> pull commands (per manifest): repo → live"
  for cmd in "${COMMAND_FILES[@]}"; do
    local repo="$REPO_COMMANDS/$cmd"
    if [ ! -f "$repo" ]; then
      echo "  WARN: manifest lists '$cmd' but repo file missing: $repo" >&2
      continue
    fi
    cp "$repo" "$LIVE_COMMANDS/$cmd"
    echo "  pulled: $cmd"
  done

  echo "live skill + commands updated. Restart Claude Code if SKILL.md or command frontmatter changed."
}

case "$DIRECTION" in
  push)  do_push ;;
  pull)  do_pull ;;
  check) do_check ;;
  *)     echo "unknown direction: $DIRECTION (use: push | pull | check)" >&2; exit 2 ;;
esac
