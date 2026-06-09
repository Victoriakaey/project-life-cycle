# Changelog

All notable changes to the `project-lifecycle` plugin are documented here.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning 2.0.0](https://semver.org/). Newest release is listed first. Comparison links below cover the release points this repository carries a tag for.

---

## [Unreleased]

Nothing yet.

## [0.4.0] - 2026-06-08

### Added

- Ships enforcement hooks: one blocks bypassing commit/push safety checks and direct pushes to the main branch, another reminds you to close out a phase properly.
- Adds an opt-in check that asks one reflection question about your own change after it ships, without keeping a running score.

### Changed

- Every pull request now opens with a short plain-language summary before the technical detail.

## [0.3.0] - 2026-05-28

### Added

- Adds `/init-harness`, which bootstraps a new or existing project with this plugin's conventions and starter documentation in one pass.
- Adds `/release`, which computes the version bump from the changelog, tags, and publishes a release automatically.
- Adds onboarding and verify-loop guides for bringing a new contributor (human or AI) up to speed safely.

### Changed

- The per-task validator now runs a lie-detection pass first, checking a builder's claims against the real diff before accepting them.

## [0.2.0] - 2026-05-27

### Added

- Adds a mandatory user-story and acceptance-criteria file for user-facing work, checked by a new independent acceptance-verifier step.
- Adds `/ship`, a command that runs one feature end-to-end (research, story, spec, build, verify, PR) with a few points where you confirm before continuing.
- Adds quality rules for optional HTML companion documents (accessibility, real data instead of placeholders, consistent styling).

### Changed

- Expands the per-task review cadence from 5 to 6 steps, adding the acceptance-verifier and a stricter, read-only validator.

## [0.1.0] - 2026-05-11

Initial release.

### Added

- Introduces the full spec → plan → execute → journal → milestone-done project workflow, plus a per-task cadence of implement → review → code-quality review → fix → journal.
- Adds a research protocol for locking design decisions, backed by a second, independent reviewer check.
- Adds Architectural Decision Records, a domain glossary convention, and delivery templates (issue breakdown, changelog, PR body).

[Unreleased]: https://github.com/Victoriakaey/project-life-cycle/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/Victoriakaey/project-life-cycle/releases/tag/v0.4.0
