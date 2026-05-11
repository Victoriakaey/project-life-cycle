# Defer-vs-Fix Triage

Reviewers flag findings as Critical / Important / Minor / Forward-looking. Critical = block; Minor = backlog. Important findings are the ambiguous ones — applying a single rule prevents drift.

## The Rule

**Fix now if (any of):**
- Affects user-visible behavior in the current milestone (broken UX, wrong data shown, data loss path).
- Affects a downstream task in the same milestone or the next one (forward-looking finding).
- Closes a security or compliance hole.
- Locks in a contract that other code is about to consume.

**Defer to backlog if (all of):**
- The finding is real but doesn't bite right now.
- No downstream task in the next 1-2 milestones depends on the fix.
- A backlog entry with explicit Trigger + Exit criteria can be written.

## Backlog format

When deferring, write the backlog entry before closing the task:

```markdown
### <date>-<scope>: <one-line summary>

**Trigger** — when does this become urgent? (e.g., "milestone N starts", "row count exceeds X", "user count grows past Y", "feature Z ships")
**Exit criteria** — what does "fixed" look like? Specific test, behavior, or measurable property.
**Origin** — where was it raised? (review of task K, journal entry M, ADR N)
```

Without explicit Trigger + Exit criteria, backlog items rot.

## Anti-patterns

- "Mark as Important then close the task" — silent drift; fix it or write the backlog entry.
- "Fix later" without a backlog row — guaranteed to be forgotten.
- "Defer everything because the milestone is closing" — a Critical finding is still Critical at milestone close.
- "Fix everything because we're being thorough" — wastes review cycles on issues that will never bite.
