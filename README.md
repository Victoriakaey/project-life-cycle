# project-lifecycle

A [Claude Code](https://docs.claude.com/en/docs/claude-code) skill that enforces a **traceable, multi-phase software project workflow**: spec → plan → execute → smoke → handoff → PR → milestone-done. One skill, every project, same discipline.

## Why this exists

If you ship features through an AI agent and you don't want to re-explain your dev process every time you start a new project, this skill is the contract. It encodes:

- **Doc-first cycle**: every phase produces a spec, plan, journal, and handoff doc before merge.
- **Per-task 5-step cadence**: implementer → spec review → code review → fixup → journal entry.
- **Dual-track smoke**: a manual checklist (real browser/device) plus an automated Playwright (or equivalent) E2E. Both required for user-visible phases.
- **Phase delivery handoff doc**: a single 8-section deliverable that lets a product owner verify and merge in 5 minutes without reading code or `git log`.
- **Findings tier triage**: S1 blocks merge, S2 ships with a follow-up issue, S3 captured for later.
- **Cost-aware behaviors**: offset+limit reads, compact CLI output flags, a codemap pattern, and adopt-tier guidance for RTK / token-savior / caveman.
- **Atomic commits, push-immediate, branch+PR per phase, English commits**, no `--no-verify`, no amend on published commits.

This isn't a code generator. It's a **process layer** that wraps the underlying [`superpowers:*`](https://github.com/obra/superpowers) skills (brainstorming, writing-plans, subagent-driven-development, etc.) with conventions that make AI-driven multi-phase development auditable.

## What ships in this skill

```
skills/project-lifecycle/
├── SKILL.md                              ← entry point, 9-step per-phase workflow
└── references/
    ├── cadence.md                        ← 5-step per-task cadence (implementer → reviews → fixup → journal)
    ├── handoff-template.md               ← 8-section phase delivery doc + PR-body appendix
    ├── smoke-tracks.md                   ← dual-track smoke contract (manual + Playwright)
    ├── findings-tier.md                  ← S1/S2/S3 triage rules and findings format
    ├── milestone-done.md                 ← closing-the-milestone gate
    ├── journal-schema.md                 ← 6-section journal entry template
    ├── research-gate.md                  ← when online research is required before deciding
    ├── defer-vs-fix.md                   ← triage rule for review findings
    ├── cost-aware-behaviors.md           ← per-token leverage rules + tool-adopt tiers
    └── origin.md                         ← pilot history
```

## Installing (via Claude Code marketplace)

```bash
# 1. Register this repo as a Claude Code plugin marketplace
claude plugin marketplace add Victoriakaey/project-life-cycle

# 2. Install the skill
claude plugin install project-lifecycle@project-life-cycle
```

After install, the skill becomes available as `project-lifecycle` in your Claude Code session and is invoked automatically when you start a new project, plan a new milestone, or run per-phase work.

To uninstall:

```bash
claude plugin uninstall project-lifecycle@project-life-cycle
```

## Using the skill

### When it triggers

The skill auto-triggers when Claude detects you're:

- Starting a new project (`RESUME.md` / `iteration-journal.md` absent)
- Planning a new milestone
- Executing per-phase work with spec / plan / journal artifacts
- Closing a milestone (running the done-gate)

You can also invoke it explicitly: tell Claude "use the `project-lifecycle` skill".

### Where output documents land

The skill writes structured artifacts to your project's `docs/` tree:

| Artifact | Path | Owner |
|---|---|---|
| Brainstorm Q&A log | `docs/brainstorming-qa-log.md` (append-only) | brainstorming step |
| Phase spec | `docs/superpowers/specs/YYYY-MM-DD-phase-X.Y-<slug>-design.md` | design contract |
| Phase plan | `docs/superpowers/plans/YYYY-MM-DD-phase-X.Y-<slug>.md` | execution plan |
| Research notes | `docs/research/YYYY-MM-DD-mX.Y-research.md` | pre-spec synthesis |
| Mid-phase questions | `docs/research/YYYY-MM-DD-mX.Y-mid-phase-questions.md` | uncertainty log |
| Mid-phase resume note | `docs/research/YYYY-MM-DD-mX.Y-resume-note.md` | session-boundary handoff |
| Manual smoke checklist | `docs/research/YYYY-MM-DD-mX.Y-smoke-checklist.md` | Track A manual smoke |
| Smoke findings | `docs/research/YYYY-MM-DD-mX.Y-smoke-findings.md` | smoke-discovered issues + tier |
| Phase delivery handoff | `docs/handoff/YYYY-MM-DD-phase-X.Y-handoff.md` | the doc that drives the PR |
| Per-task journal | `docs/iteration-journal.md` (append-only) | per-task progress |
| Milestone log | `docs/RESUME.md` § "Phase X.Y progress" | project state |

The Playwright (or equivalent) E2E spec lives in your frontend / test directory and is referenced from the handoff doc.

### Suggested project conventions

Add a `Makefile` (or equivalent task runner) target:

```make
phase-checks:
	cd backend && pytest $$( [ -n "$$PHASE" ] && echo "-k $$PHASE" || echo "" ) -q
	cd frontend && pnpm exec vitest run $$( [ -n "$$PHASE" ] && echo "-t $$PHASE" || echo "" )
	cd frontend && pnpm exec playwright test $$( [ -n "$$PHASE" ] && echo "e2e/m$$PHASE-*.spec.ts" || echo "" )
```

`make phase-checks PHASE=X.Y` produces the test-results evidence that feeds the handoff doc §5 and §6.

Add a `make codemap` target (optional) per `references/cost-aware-behaviors.md` — generate per-app / per-zone symbol indexes so Claude doesn't have to grep large files when locating a definition.

## Layering with project-specific rules

This skill is the **universal** workflow. Your project's `CLAUDE.md` should only carry **project-specific** rules: tech stack, audience, business invariants, glossary, escalation categories. Anything cross-project belongs in this skill — propose changes via PR.

Example project-specific `CLAUDE.md`:

```markdown
# Project: <name>

## Workflow contract

The universal workflow lives in the `project-lifecycle` skill. This file only captures project-specific additions:

1. Audience priority — <who>
2. Research reference tiers — <which sources this project cites>
3. Tech stack — <stack>
4. Domain invariants — <rules>
```

## Contributing

This skill evolves through real project use. If you find a pattern that should be encoded across projects:

1. Open an issue with the use case
2. Or open a PR against the relevant `references/` file with the rule + a concrete example from your project

Findings from real phases beat speculative rules.

## License

MIT — see [LICENSE](LICENSE).
