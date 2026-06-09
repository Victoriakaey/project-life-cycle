# Self-Update Flow

How an AI agent (the assistant using this skill) updates the skill itself when the user says "update the workflow" / "add this rule" / "change how we do X."

The skill lives in two places:

- **Live**: `~/.claude/skills/project-lifecycle/` — edited directly, takes effect on next session start.
- **Repo**: cloned somewhere local + pushed to GitHub — the publish boundary; how other users / projects get updates.

Both must stay in sync. The mechanism is `scripts/sync.sh` from the repo.

## When to update the skill (vs. a project's CLAUDE.md)

When the user asks for a rule change, FIRST decide scope:

| Signal | Update the skill | Update project's CLAUDE.md |
|---|---|---|
| Rule applies to every project the user runs | ✅ | ❌ |
| Rule about a specific stack (Django, Rails, Postgres) | ❌ | ✅ |
| Rule about a specific business domain (accounting, healthcare) | ❌ | ✅ |
| Rule about specific tools (RTK, caveman) | ✅ (adopt-tier doc) | ❌ |
| Rule about the per-phase workflow itself | ✅ | ❌ |
| Rule about audience / mom-test / industry references | ❌ (project-specific) | ✅ |
| The user explicitly says "add this to the project-lifecycle skill" | ✅ | ❌ |
| First time seeing this pattern, not yet proven cross-project | ❌ (try in CLAUDE.md first, promote later) | ✅ |

**Default when ambiguous:** put it in the project's CLAUDE.md. Promote to the skill only after the same rule has been useful in ≥2 projects, or the user explicitly says it should be universal.

## Default update flow (no release)

Triggered when user says: "update the workflow to X", "add this rule to the skill", "note this for future projects", etc. (the user's actual wording may be in any language; intent = cross-project scope).

```
1. Confirm scope (skill vs project CLAUDE.md) — ASK if ambiguous.
2. Edit ~/.claude/skills/project-lifecycle/SKILL.md or references/<file>.md.
2b. If you touched the skill's `hooks/` (frontmatter hook scripts or the
    SessionStart template), run `hooks/test-hooks.sh` and confirm all green BEFORE
    sync — a broken `hooks:` block can stop the skill loading. See
    `references/harness-primitives.md` §1.
3. Run the repo's sync script:
     ~/Projects/<repo-name>/scripts/sync.sh push --commit
   (sync rsyncs live → repo, runs validate.py, commits, pushes to origin.)
4. Tell the user: "Updated skill — restart Claude Code to apply, OR continue this session (live skill changes don't reload mid-session)."
5. NO version bump, NO tag, NO release. Edits accumulate; release is a separate explicit step.
```

## Release flow (explicit, version-bumping)

Triggered ONLY when user says: "release vX.Y.Z", "ship the skill", "tag a release", or equivalent explicit publish intent in any language. Never auto-triggered.

```
1. Decide semver bump:
   - Patch (0.1.0 → 0.1.1): typo, wording, internal clarification
   - Minor (0.1.0 → 0.2.0): new reference doc, new rule, new tool tier
   - Major (0.1.0 → 1.0.0): breaking convention change (e.g., renamed handoff
     section, dropped a required gate). Ask user before going major.
2. Edit BOTH .claude-plugin/marketplace.json and .claude-plugin/plugin.json.
   Set "version" to the new semver. Both files MUST match exactly.
3. Commit: git commit -am "bump: vX.Y.Z"
4. Tag: git tag vX.Y.Z (or `claude plugin tag .` which validates manifests agree)
5. Push: git push && git push --tags
6. release.yml workflow runs, generates changelog from commits, creates a
   GitHub Release.
7. Tell the user: "Released vX.Y.Z. Other installs can pull via
   `claude plugin marketplace update project-life-cycle && claude plugin update project-lifecycle`."
```

## Mid-phase update safety

If the user asks to update the skill while mid-phase on another project:

1. Note that the live skill change won't apply to the CURRENT session — only to the next session that starts after the change.
2. If the rule is about the active project's process, prefer putting it in that project's CLAUDE.md first (immediate effect, low risk).
3. The skill update can wait until after the active phase ships, OR happen now if it's a no-op for the current phase.

Never push a skill change mid-phase if it could change the current phase's exit criteria. That's a moving-target violation of the milestone-done gate's contract.

## What to write down vs. what to verify first

The user might say "we should always do X" in a moment of frustration. Before editing the skill:

- Has this happened ≥2 times across projects? If only once, it might be project-specific.
- Is the user proposing a rule, or just venting? Clarify if ambiguous.
- Will adding this rule conflict with an existing rule? If so, surface the conflict — don't silently override.

The skill is the high-water mark of process discipline. Adding a rule means every future project pays a small attention cost reading it. The bar is "I've been bitten by this enough times that future-me wants reminding."

## Anti-patterns

- **Auto-bumping version on every edit** — pollutes Releases with non-events. Bump only on explicit release.
- **Editing the repo skill (`~/Projects/.../skills/...`) directly without rsync from live** — drift between live and repo, then sync.sh check will fail. Always edit live, then `sync.sh push`.
- **Updating the skill mid-phase when the change affects the current phase's criteria** — moving target. Wait or scope the change to project CLAUDE.md.
- **Adding rules without checking if they conflict with existing references** — duplicates and contradictions hurt more than no rule.
- **Skipping validate.py** — `sync.sh push` runs it automatically. Don't bypass.
- **Cherry-picking rules from one project into the skill without abstracting them** — project-specific glossary entries or a particular audience label (e.g. "novice users in vertical X") do NOT belong in the universal skill; promote the *pattern* (in-context help on novice surfaces, audience-priority concept) without project specifics.

## Bootstrapping a fresh agent

If a new Claude Code session starts and the user says "update the workflow," the agent should:

1. Read this doc (`references/self-update-flow.md`) first.
2. Find the repo via the user (or search common locations: `~/Projects/project-life-cycle`, `~/Code/`, `~/repos/`, etc.).
3. Confirm the live skill at `~/.claude/skills/project-lifecycle/` matches the repo's `skills/project-lifecycle/` via `scripts/sync.sh check`. If drift, ask the user which direction to sync first.
4. Proceed with the update flow above.
