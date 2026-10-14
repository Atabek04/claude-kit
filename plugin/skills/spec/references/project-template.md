# <Project>: spec context

Read by the `kit:spec*` skills. Each section holds only what differs in this project; point to owner files, never
copy them. Write "none" for a section that does not apply.

## Paths

Spec directory (`docs/specs/<name>/`), any legacy file layout, and the failure log (`.claude/spec/failure-log.md`).

## Owners

Where each kind of fact lives: product intent, stack and versions, schema, API, design, decisions and rejections.

## Shape

The architecture in one screen: modules or stacks, data flow, the boundaries a spec must respect, budgets.

## Search surface

What to search before claiming something is new: migrations, schema docs, API docs, routes, screens.

## Approval

Who approves `spec.md`, which decisions are reserved for them, and whether the `approved` marker is required.

## Spec rules

Additions to `kit:spec-write`: the project's unhappy paths, the chairs that test a pick, what Changes must carry.

## Review checks

Checklist lines `kit:spec-review` adds for this project: hard rules, boundaries, touch points a delta must list.

## Tasks

Additions to `kit:spec-tasks`: path patterns, `Verify:` command forms, where tests live for the `Unlock:` search.

## UI design

How a `[UI]` spec gets its `## Chosen design` before tasks, and what the UI line of the spec header lists.

## Branch and worktree

The branch name per spec and where its checkout lives.

## Implementation

Project musts for "One batch" step 7: skills to load, stack rules, generated files to refresh, risk-area reading.

## Gate

The commands that make a batch green, and the review that runs after it by hand.

## Loop

For `--loop`: gate command, test lock, reviewer agents, extra briefing constraints, or "not used" and what replaces it.

## Commits

Message format, staging rules, attribution.

## Landing

The steps once every criterion is ticked: full gate, docs, backlog, merge or push.
