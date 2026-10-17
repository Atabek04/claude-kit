---
name: spec
description: "Spec-driven development: spec.md (requirements and design in one file) → review → tasks.md → review → implement one batch per session, or every batch with --loop. Routes create, review, preview, tasks, implement, status and list. Use proactively whenever new functionality is about to be built, even unasked: \"write a spec\", \"plan this feature\", \"implement this\", \"add a feature\", \"break into tasks\"."
argument-hint: "create|review|preview|tasks|implement|status|list [name] [B<N>|T<N>|--loop]"
---

# Spec

**First read `.claude/spec/project.md` at the repo root** (`git rev-parse --show-toplevel`). "project.md X" below means
its section X. If the file is missing, stop: offer to create it from
[references/project-template.md](references/project-template.md), filled from the repo's `CLAUDE.md` and docs, and do
nothing else until the user agrees.

A spec is `spec.md` and `tasks.md` in the directory project.md "Paths" names. `spec.md` carries two markers:
line 1 `<!-- reviewed: <sha> -->` (the review seal, written by `kit:spec-review`) and, when project.md "Approval"
requires it, line 2 `<!-- approved: <YYYY-MM-DD> -->`, written only after the approver says so in chat.

## Commands

| `$ARGUMENTS` | Does |
|---|---|
| `create <name> "<description>"` | `kit:spec-write` → `spec.md`, then `kit:spec-review` on it |
| `review <name>` | `kit:spec-review` on the first unsealed file |
| `preview <name>` | `[UI]` specs only: project.md "UI design" |
| `tasks <name>` | `kit:spec-tasks` → `tasks.md`, then `kit:spec-review` on it |
| `implement <name>` | the first batch with an unchecked criterion |
| `implement <name> B<N>` / `T<N>` | that batch / the batch holding that task, whole |
| `implement <name> --loop` | every remaining batch, then one landing: [references/loop.md](references/loop.md) |
| `status <name>` / `list` | which files exist, sealed or not, approved or not, `n/m` criteria ticked, the next command |

**Order:** create → review → approval (when project.md "Approval" requires it) → UI design (when any story is `[UI]`)
→ tasks → review → implement. A missing step is named with its command; it is never skipped.

## One batch

The same procedure runs by hand and inside each `--loop` implementer.

1. **Locate.** Work in the spec's branch and worktree per project.md "Branch and worktree".
2. **Resume from disk.** The last three Session Log rows of `tasks.md` and `git log --oneline -15` are the state; do
   not re-derive it from the code.
3. **Read targeted.** `tasks.md` first: the batch's `Files:`, `Depends:`, `Verify:`, `Unlock:`. Then only the
   `spec.md` rules, stories and traps the batch cites. A `Depends:` batch unfinished: list it and stop.
4. **Scan in one parallel block:** glob the `Files:` paths, grep the patterns and tests they depend on, `git status`.
5. **The one stop: the batch contradicts the code.** A file the spec names is missing, a table or endpoint already
   behaves otherwise, a dependency is gone. Say so in one paragraph and stop. Size and risk are not stops: `tasks.md`
   is the approved plan. A batch too big for a session is a `tasks.md` sizing problem; split it there.
6. **Tests first, by `kit:tdd`.** Record `BASE=$(git rev-parse HEAD)`, then run its loop with the batch's criteria
   and cited rules as the case list and the seams they name as agreed (no confirmation round). On top of it:
    - Tests older than `BASE` are not edited except those `Unlock:` names. A failing one means the code is wrong or the
      spec contradicts it (step 5).
    - Tests commit with the code that makes them pass: no commit is ever red.
7. **Implement** by project.md "Implementation". A decision the spec left open is made the way `kit:spec-write`
   "Options" says and recorded in the Session Log; a decision project.md "Approval" reserves is a blocker, never a
   guess. A library a task names is installed, never replaced by an inline version. Nothing beyond the tasks'
   deliverables.
8. **Gate:** the batch's `Verify:` line, then project.md "Gate", every job green. Read the exit code and every job
   line, never a truncated listing. Then run `kit:review <BASE>` with this
   spec and fix every P0 and P1 before recording.
9. **Record.** Tick the batch's criteria (never one that no code and test back), append the Session Log row
   `| <date> | B<N> | <sha> | done, gates green | <decisions and blockers> | <next> |`, and add a failure-log row for
   each thing that actually broke. Commit per project.md "Commits", each commit compiling on its own.
10. **Do not push** unless asked. A batch that leaves unchecked criteria ends here: name the next batch and recommend
    `/clear`. The batch that ticks the last criterion lands the spec.

## Landing

When no unchecked criterion is left: project.md "Landing", then the failure-log scan below.

## Failure log

The log (path in project.md "Paths") replaces re-approving each batch: the cost is paid once, after a batch goes
wrong, and buys a rule that makes the class of error impossible next time.

- **One row per thing that actually broke** (a red gate, a wrong assumption about the spec, a duplicated utility, a
  reviewer finding). Nothing broke: add nothing; a padded log is worthless.
- Row: `| date | spec/batch | what went wrong | rule that should have caught it, or "none, gap" | source | strength |
  status |`. Source: self-review, gate, CI, reviewer, independent tests, user. Strength: strong, medium, weak.
  Status: `open`, `fixed: <how>`, `PROMOTED → <rule>`, `STALE`.
- **At landing, scan for classes.** A class seen three times changes a rule, and its rows are marked `PROMOTED →`.
  A rule every project needs goes into these kit skills; a project-only rule into project.md. Never promote from one
  incident.
- **A hook or a test beats a sentence.** Anything mechanically checkable becomes a gate, not prose.
- Mark a rule that has not fired in months `STALE`.

## Rules

- **The batch is the unit.** Never implement half a batch; a named task resolves to its whole batch.
- **By hand, never delegate a batch to a subagent:** reading the code is the work, and a summary of it is not the
  context. Under `--loop` the subagent is the batch session and the orchestrator reads no code.
- **No speculative structure.** Before a pattern (factory, strategy, wrapper), name the language idiom that already
  solves it. The simpler solution wins.
