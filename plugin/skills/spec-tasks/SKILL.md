---
name: spec-tasks
description: "Turns a reviewed (and, where the project requires it, approved) spec.md into tasks.md: ordered vertical batches, one per session, that /kit:spec implement runs. Use for \"/kit:spec tasks\", or \"break this spec into steps\" and \"what do I build first\" once spec.md is sealed and has no tasks.md; normally run via kit:spec."
---

# Task generator

Read `.claude/spec/project.md` at the repo root first; if it is missing, follow `kit:spec` (stop and offer the
template). Produces `tasks.md` beside `spec.md` from [references/tasks-template.md](references/tasks-template.md),
then invokes `kit:spec-review` on it.

## Preconditions

Refuse, write nothing, and name the command that fixes it:

- `spec.md` has no `<!-- reviewed: … -->` seal: "Run `/kit:spec review <name>` first."
- project.md "Approval" requires approval and `spec.md` has no `<!-- approved: … -->` line: "The approver approves
  `spec.md` before tasks."
- A `[UI]` spec whose `## Chosen design` is empty or pending: "Run `/kit:spec preview <name>` first."

## Batches

A batch is one session's vertical slice: it delivers one capability a user, a caller or an agent can use, and leaves
the branch compiling with the gate green.

1. **Every batch states what users or callers can now do,** in one sentence. If it cannot, it is a layer, not a
   slice. **Risk first,** as far as dependencies allow: a new architecture, an integration, a new synced or shared
   table, an unknown before standard features, polish last. A spec that is going to fail should fail in B1.
2. **No horizontal batches.** A batch carries every layer its capability needs, with its tests. Infra alone (an API
   client, a nav link) folds into the first batch that uses it.
3. **At most six tasks per batch, one capability.** No floor.
4. **`Files:`, `Depends:` and `Verify:` are mandatory.** `Verify:` is commands a fresh session runs unattended, in
   the forms project.md "Tasks" names. A criterion only a browser or a device can prove names its command or agent in
   `Verify:`, or is tagged `[manual]`.
5. **`Unlock:` is found by search, never from the spec's text.** For each symbol, label, route, column or flow a batch
   deletes, renames or changes, grep the existing tests (project.md "Tasks" says where). Every test that pins the old
   behaviour is an `Unlock:` entry with one clause on the rule that changed. Omit the line only when the grep finds
   none.
6. **A new public name is grepped before it is written** (an export, a route, a class, a table): a collision is
   renamed here, not found at compile time.
7. **A criterion must hold with only this batch and earlier ones delivered.** Write the intermediate state and say in
   one clause what the later batch adds.
8. **UI batches build `## Chosen design`** per project.md "UI design".

## Tasks

- Numbered `T1 … Tn` across the whole spec, never restarted per batch.
- A task is a heading, one **Deliverable** line, and checkbox criteria. `[P]` marks a task that shares no file and no
  dependency with its siblings. No estimates.
- Every story criterion in `spec.md` lands in exactly one task. A criterion with no story is scope creep.

End the file with an empty `## Session Log` table; implement appends to it.

## Hand-off

Once `tasks.md` is reviewed and sealed, end with the exact command for the owner to paste into a fresh session in the
spec's worktree, as one fenced block, and one line on why:

| Plan | Paste |
|---|---|
| One batch | `/kit:spec implement <name>` |
| Several batches, B1 risky | `/kit:spec implement <name> B1`, then after the owner has read it, `/kit:spec implement <name> --loop` |
| Several batches, nothing risky | `/kit:spec implement <name> --loop` |

When project.md "Loop" says the loop is not used, paste `implement <name>` and name what replaces the loop.
