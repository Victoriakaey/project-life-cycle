# Iteration Journal Entry Schema

Per-task entries (covering all of the task's commits, not each individually) appended to `docs/iteration-journal.md`. Six required sections.

## Template

```markdown
## Milestone N.M Task K — <one-line summary>

- **Date:** YYYY-MM-DD
- **Commits:** <feat-sha> + <fixup-sha(s)> + journal <docs-sha>
- **Refs:** plan §"..." (path:line); spec §...; research <doc>.

**Observations** — Why does this task exist? What state of the world does it address? What did you notice while working on it that wasn't obvious from the plan?

**Motivations** — Three to five design choices. Each one a paragraph: what was the choice, what alternatives were considered, why this one wins.

**What changed** — File-by-file (or component-by-component) summary of the actual diffs. Should be readable as a description of the change-set, not a re-listing of the file paths.

**Plan deviations** — Required header. If there are no deviations, write "none". If there are, enumerate each:
- What the plan said
- What was actually done
- Why the deviation was necessary or beneficial
Plans always drift; the drift is the most valuable signal for future audits and onboarding.

**Impact** — What can the project / users / future tasks now do that they couldn't before? Include test counts, coverage numbers, and any cross-cutting effects.

**Final verification** — Bullets: targeted test count, full-suite count, coverage, lint, build, schema-drift checks. The actual numbers — this is the audit trail.
```

## Why these six sections

| Section | Bug class it catches |
|---|---|
| Observations | "We forgot why we did this 3 months later" |
| Motivations | "We picked X but no one remembers what we rejected" |
| What changed | Code review without re-reading the diff |
| Plan deviations | Silent drift; audit / onboarding gaps |
| Impact | "Did anyone actually verify the milestone goal moved forward?" |
| Final verification | "Did tests run? Was lint clean?" |

## Anti-patterns

- **Per-commit journal entries.** One entry per task; the task's commits roll up.
- **Skipping "Plan deviations" because there are none.** Keep the header with "none" — its presence forces the active drift check.
- **Narrative storytelling.** This is a project audit log, not a blog post. Bullet-style facts beat narrative prose.
- **Numbers without source.** "All tests pass" is not enough. "N passed + 1 xfailed in 8.3s, coverage 95%" is — the point is that the numbers are there and sourced.
- **Linking to commits without inline summary.** Reader shouldn't have to context-switch to git to understand what shipped.
