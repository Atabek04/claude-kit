# Report mode: no merge request

Used when the target is a module, a path, a branch with no MR, `HEAD` or `staged`, or when `--save` is given.
The engine is the same as in MR mode; only the output channel differs: a markdown report instead of threads.

## Plan first, visibly

Before deep reading, print one block: target, file count by kind, what is read fully, what is spot-checked, what is
skipped with a reason, and the loaded references. A module or `path:` review reads fully every controller, service,
repository, client, migration and job in scope, spot-checks entities and DTOs, and samples tests; any skipped category
is named with its reason.

## Report

Written to the project's review path, else `docs/reviews/<YYYY-MM-DD>-<scope>-<target>.md`, never overwriting one.

```
# Review: <scope>, <target>
**Date** · **Target** (<N> files, +X/-Y) · **Base..Head** · **Tier** · **References**
## Summary        counts per severity, worst per axis, verdict, intent match
## Since previous review   (re-review only) fixed | open | declined | disputed per earlier finding
## P0 / P1 / P2 / P3       one block per finding: title, where, rule or spec line, input → effect → fix
## Pre-existing           one line each
## What looks good        specific, short
## Coverage notes         read fully, skimmed, skipped with reason, pre-scan table, verifier tally, what was not run
```

Per axis headings stay separate, as in SKILL.md section 5. A finding block is:

```
### [P1] [category] <title>
**Where:** path:line · **Rule:** <cited> · **Verifier:** CONFIRMED
**Problem:** <input → what happens>   **Fix:** <bounded change or 1-3 options, one marked as the pick>
```

## Fixing from a report

A review never fixes in the context that produced it. With up to five P0/P1 findings and `--fix`, fix them in this
session (hard findings first, one commit per finding, tests green). With more, end by printing a fresh-session
prompt that names the report: re-read each cited file before touching it, push back on a finding the code disproves,
one commit per finding, append a `## Resolution` section (fixed with sha, declined with reason) when done.
