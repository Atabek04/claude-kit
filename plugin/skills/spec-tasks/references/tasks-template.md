# tasks.md template

```markdown
# <Feature name>: Tasks

| Batch | Tasks | Delivers |
|---|---|---|
| B1 | T1-T3 | <Users can now …> |
| B2 | T4-T6 | <Callers can now …> |

**B1** <delivers line>
- **Files:** `<path>` (new), `<path>`
- **Depends:** none
- **Verify:** `<test command>`; `<observable check>`

**B2** <delivers line>
- **Files:** …
- **Depends:** B1
- **Verify:** …
- **Unlock:** `<test file>` (BR-3 changes the value it asserts). Omitted when the grep finds no test.

## Tasks

### T1 (B1) <Imperative title>
**Deliverable:** <what exists when done, with the file>.
- [ ] <Testable criterion, carried from a spec.md story.>

### T2 [P] (B1) <Imperative title>
**Deliverable:** …
- [ ] …

## Session Log

| Date | Batch | Head SHA | State | Decisions and blockers | Next |
|---|---|---|---|---|---|
```

Implement marks every criterion of a finished task `[x]` and appends one Session Log row per batch. The decisions
column carries what the next batch would otherwise re-discover: a choice the spec left open, a blocker met, a file
that turned out to matter.
