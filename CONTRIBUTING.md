# Contributing

This skill evolves through real project use. Bug reports, new patterns surfaced by real phases, and refinements to existing references are all welcome. Speculative rules without a concrete example from a real project are not.

This repo follows the **same discipline the skill itself prescribes** — `references/changelog.md` is the canonical spec. The rules below are the short version applied at the repo boundary.

## Before you open a PR

1. **One change, one PR.** Mixing a new reference + a workflow tweak + a doc rewrite in one PR makes the changelog entry incoherent and the release-notes label ambiguous.
2. **Edit live first** (`~/.claude/skills/project-lifecycle/`), prove it works on a real phase, **then** push via `./scripts/sync.sh push --commit`. The repo is the publish boundary; speculative edits to the repo without trying them on a real phase produce drift the next live edit overwrites.
3. **`scripts/sync.sh check`** must pass — no drift between live and repo.
4. **`python3 scripts/validate.py`** must pass — manifest JSON, marketplace ↔ plugin name agreement, SKILL.md frontmatter, reference link integrity, command frontmatter + manifest reconciliation, UTF-8.

## Commit messages — Conventional Commits

Subset enforced:

```
<type>(<optional-scope>): <imperative summary, lowercase, no trailing period>

<optional body — wrap at 72 chars, explain WHY, not WHAT>

<optional footer — BREAKING CHANGE: …, refs #123, etc.>
```

| Type | Maps to | When |
|---|---|---|
| `feat` | MINOR (SemVer) | New feature, new reference, new command |
| `feat!` (or `BREAKING CHANGE:` footer) | MAJOR | Breaking convention / API / file-layout change |
| `fix` | PATCH | Bug fix users would observe |
| `docs` | (no bump) | Docs-only change |
| `refactor` | (no bump) | Internal restructure with no behavior change |
| `chore` | (no bump) | Tooling / housekeeping |
| `ci` | (no bump) | CI / workflow change |
| `sync` | (no bump) | Routine live → repo mirror (`./scripts/sync.sh push --commit` default) |

English on durable artifacts (commit, PR body, CHANGELOG, code comments). Chat / Q&A / project journal entries may use the user's preferred language; the repo boundary stays English so it's greppable across reviewers + projects.

Never use `--no-verify` to skip a hook. Fix the hook complaint.

## PR title

PR title MUST use Conventional Commits style. This is what GitHub auto-release-notes displays alongside the PR number when a release is cut.

Bad: `Adds the new validator`
Good: `feat(cadence): add read-only validator at step 2`
Good: `feat!: split implementer into BE + FE builders (breaking)`
Good: `fix(sync): rsync now honors commands manifest exclusions`

## PR body — mandatory 3-section format

Use the template in `skills/project-lifecycle/references/handoff-template.md` §"PR description appendix":

```markdown
## 1. What was done
<2-4 sentence plain-English prose intro>
### Use cases (REQUIRED for new user-facing features)
<scenario table + comparison to existing surfaces + alternatives>
### Files
<file-by-file bullets>

## 2. Why this approach
<design decisions + trade-offs + engineering alternatives rejected>

## 3. Requirements satisfied
- ✅ spec §X.Y — what spec section this closes
- ✅ plan task N — what plan task this completes

## Changelog + label (MANDATORY pre-merge checklist)
- [ ] Added one-line bullet to `CHANGELOG.md` `[Unreleased]`
- [ ] Applied exactly one category label
- [ ] PR title in Conventional Commits style
```

§1 prose intro is non-negotiable; file bullets alone don't tell reviewers what the PR does. The §1 intro is what GitHub surfaces in release notes.

## PR label — exactly one

Pick one from the taxonomy. The label drives the auto-generated release notes via `.github/release.yml`.

| Label | Use when |
|---|---|
| `breaking` | Breaks API / convention / file layout; requires migration |
| `feature` | New user-visible capability |
| `new-reference` | New `skills/.../references/<file>.md` |
| `new-command` | New slash command shipped via `commands/` |
| `cadence` | Edits to `references/cadence.md` (per-task discipline) |
| `workflow` | Edits to SKILL.md numbered per-phase steps |
| `convention` | New / changed Mandatory Convention or Red Flag |
| `bug` / `fix` | Bug fix |
| `docs` | Docs-only |
| `ci` / `tooling` / `sync-script` | CI workflow / validator / sync mechanism |
| `dependencies` | Bumps + lockfile updates |
| `chore` | Repo housekeeping |
| `sync` | Routine `sync:` commit (excluded from release notes) |
| `skip-release-notes` | Explicit opt-out for internal-only churn |

Uncategorized PRs land in "Other Changes" catch-all → fix before merge.

## CHANGELOG entry — mandatory for user-visible changes

Add a one-line bullet to the `[Unreleased]` section of `CHANGELOG.md` in the same PR. Pick the right Keep a Changelog category:

| Category | When |
|---|---|
| `Added` | New feature, new reference, new command, new public API |
| `Changed` | Modifications to existing behavior, refactors that change user-visible output |
| `Deprecated` | Soon-to-be-removed features still present and working — announce BEFORE removing |
| `Removed` | Features deleted |
| `Fixed` | Bug fixes users would observe |
| `Security` | Vulnerability patches, secret rotations, hardening |

Bullet must name the artifact (file / endpoint / command / convention) by its real identifier so it's greppable.

Bad: `Improved the cadence`
Good: `Cadence step 2 renamed from "spec compliance review" to Validator; now strictly read-only and reads user-story.md as ground truth`

Exempt PRs (no changelog line required):

- Routine `sync:` commits between live and repo (label `sync`).
- Internal-only refactors with zero user-visible delta (label `chore-quiet` or `skip-release-notes`).
- Test-only additions that don't change behavior (label `chore`).
- Comment-only / formatting-only changes (label `chore`).

When in doubt, add the entry.

## Cutting a release

1. Decide SemVer bump from the `[Unreleased]` set:
   - **MAJOR** if any `breaking` PR is in.
   - **MINOR** if any `feature` / `new-reference` / `new-command` is in.
   - **PATCH** if only `fix` / `docs` / `chore` are in.
2. In `CHANGELOG.md`: rename `## [Unreleased]` → `## [X.Y.Z] — YYYY-MM-DD`; add a fresh `## [Unreleased]` block above; update the compare links at the bottom.
3. Bump the version in all six SemVer manifests to the same value:
   ```bash
   $EDITOR .claude-plugin/marketplace.json
   $EDITOR .claude-plugin/plugin.json
   git commit -am "chore(release): vX.Y.Z"
   ```
4. Tag + push:
   ```bash
   git tag vX.Y.Z && git push --tags
   ```
5. GitHub Actions `release.yml` builds the GitHub Release. The release-notes body is auto-generated from PR labels via `.github/release.yml`. Optionally append the CHANGELOG section to the release body for prose context.

CI validator rejects mismatched manifest versions; never bypass.

## Repo layout pointers

- `skills/project-lifecycle/SKILL.md` — entry point, 10-step per-phase workflow.
- `skills/project-lifecycle/references/` — per-topic discipline files. Edit live first.
- `skills/project-lifecycle/references/changelog.md` — canonical discipline spec; mirrored in this CONTRIBUTING.md.
- `commands/` — slash commands shipped with the plugin. Add via `scripts/commands-manifest.txt`.
- `scripts/sync.sh` / `scripts/validate.py` — live ↔ repo bridge + validator.
- `.github/release.yml` — release-notes label taxonomy (PR labels → release-notes sections).
- `.github/workflows/validate.yml` — CI validator on every push / PR.
- `.github/workflows/release.yml` — tag-driven GitHub Release builder.

## Reporting bugs / proposing patterns

Open an issue with:
- **The use case** — what real project / phase surfaced this?
- **The pain** — what went wrong with the current convention?
- **A concrete example** — show the diff / file / commit you wish had behaved differently.
- **A sketch of the fix** — optional but speeds review.

Findings from real phases beat speculative rules.
