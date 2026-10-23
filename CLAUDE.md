# Global rules

## Source of truth: `Atabek04/claude-kit`

This file, `rules/`, and every skill, agent, hook and CI gate shared by more than one project live in `~/claude-kit`
on every machine. `~/.claude/CLAUDE.md` only imports this file; a project's `CLAUDE.md` holds only what is true of
that project. How to use and change the kit: `~/claude-kit/README.md`.
- **Propose, then apply.** A lesson that would help every project ends your report as one line,
  `Kit: <rule> -> <file>`. On the user's yes, apply it per the README's "Changing the kit"; never into a project file.
- Everything in the kit is safe to publish: no secrets, no employer, client or product names, no home paths.

## Instructions are context

Every loaded line competes for attention, and accuracy falls as context grows. Rules are principles and pointers,
never tutorials; each line must prevent a real mistake. Where a rule belongs and how to write it:
`rules/instructions.md`, which loads whenever an instruction file is edited.

## Decisions

- With more than one viable path, list the real options with what each costs to build, what it risks or violates,
  and what it costs later; then recommend one. Never a menu without a pick.
- Decide what a later edit can reverse (names, layout, copy within the rules) and report the call in one line.
  Escalate only what a rule reserves (schema, API, an approved spec, product scope): options, **the pick**, and why
  it beats the runner-up in at most two sentences. Check a "just a name" for collisions in code, UI and schema first.
- Value to the end user decides; effort never drops an idea. Reject only on value, and say why.
- A plan that satisfies a requirement's letter while breaking its context (an enforced boundary, another phase's
  ownership) is the easy fix. When the requirement is what is wrong, amend the document, say why, then build.
- Prove absence: state the search and the count. "I did not find X" and "there is no X" are different claims.
- Before a change narrows or drops what an approved requirement promised, stop: quote the requirement, give the
  options with their cost, and ask its owner. A technical constraint justifies a question, never a silent change.
- Every report separates what was run from what was only read or inferred; an untested claim says so.
- Suggest a next step only when it changes the user's next move, and name the trigger it waits for; no menus.

## Code

**The code says what, the comment says why, the name says both.** Unclear code: rename, then restructure, then
comment.
- Comment only for: a non-obvious why, a contract the signature cannot carry (units, ranges, privacy, idempotency,
  ordering), a trap, an external standard or upstream bug the code obeys, deliberate weirdness.
- Never: restating code or names, including values, statuses or branches the code below spells out; step narration;
  banners and section labels; signature-echo doc tags; class headers that repeat the name; a second copy of another
  declaration's doc (link it: `[Type]`); retelling an upstream system's behaviour beyond the one clause that is the
  why; commented-out code; ceremony; praise or hedging; what an artifact lacks; claims the code does not make true.
- API schema descriptions state the rule the consumer sees, never our internals or upstream systems.
- No doc on a small method whose name and signature already say it all, getters and overrides included. A long or
  tricky method keeps one line of intent or why: a missing why costs more than a stale one.
- A "what" comment over a block means extract a method named after that what.
- **A comment must be true for a reader who never sees this diff.** No changelog ("removed", "used to", dates) and no
  investigation transcript; state the conclusion and the constraint. A timeless warning ("deliberately not X,
  because Y") stays.
- No scaffolding IDs (spec, ticket, batch, task): state the rule in words or drop it. No roadmap ("for now", "until X
  exists"): plans go to the backlog; the only TODO is `TODO(<backlog file>#<item>): <what>`.
- Length: one line is the target, two for a tricky method, three only for a large public API; `no-slop.sh` blocks a
  fourth (the `kit` plugin, and in CI via `Atabek04/claude-kit/hygiene`) and the 120-char width. A well-named class
  carries 0-3 comments. Reread a comment whenever its code changes.
- A method name is a verb phrase carrying its object (`findActiveBookings`), never a bare `get()`/`find()`/`run()`.
- Naming: no `data`/`result`/`item`/`temp` as a whole name, no `*Manager`/`*Helper`/`*Util`/`*Wrapper`/
  `*Container`/`*Processor`, no `utils`/`helpers` files, no `handle()`/`process()`, no `XServiceImpl` for a single
  impl, no boolean parameters, no `getX()` that does I/O or mutates (`fetchX`, `loadX`). Same concept, same word.
- One way per job: grep for the existing utility, client, error shape or UI primitive first; extend it, never fork
  it. A class or file used from one place that adds no abstraction gets inlined.

## Gates

A hook, linter or CI gate that blocks you leaves three moves: fix the code, fix the gate, or escalate. Never rephrase
past a pattern, disable a gate, widen an ignore list without a stated reason, or regenerate a baseline over new
violations; evasion is worse than failure because the diff looks like compliance. A false positive is a gate bug,
fixed the same day with an allow and a deny case, and logged where that gate keeps its log.

## Files and shell

Read/Edit/Write for every file change: `Edit` fails loudly on a mismatch, `sed -i` and scripted writes fail silently.
The `kit` hook `block-inplace-edits.sh` enforces this, because the auto-mode reminder says the opposite and prose
loses. A deliberate bulk refactor needs the user to run `bulk-edit N` in their own terminal; never touch the gate
file. Inside the window: show the change map, make the script print the changed-file count, then grep that the old
string is gone. Never claim an edit succeeded without evidence.

Never kill processes by a pattern match (`pkill -f`, a `ps | grep` list): the job that writes a file matches as
well as the loops waiting on it. Read each candidate's full command and its child processes, then kill by PID.

## Libraries

Read current docs through the `context7` MCP before writing or recommending code against any library, framework, SDK
or API (load its tools with `ToolSearch` "context7"; fallback: WebFetch
`https://context7.com/api/v1/search?query=<library>`, and say so). Take exact versions from the registry or GitHub
releases, cited with the read date. Every research brief names context7 and the fallback.

## Subagents

- The main session plans, writes briefs, reviews reports and folds fixes into the rules; workers execute. A worker
  carrying out a written spec runs on `sonnet`, pure search on `haiku`, `opus` only for an open design question
  (say why in the description).
- At most 4 workers at once. Before more than 5 in total, state count, model and rough tokens (~250k each) and wait.
- A brief names the files the worker may touch, those it must not, the checks it runs and the report it returns.
  Gaps it reports are fixed in the brief, not by the worker.
- `isolation: "worktree"` branches from the default branch: for feature-branch work, create each worktree from the
  branch HEAD yourself (`git worktree add -b <branch> <path> <sha>`) and name it in the brief.

## Git

Conventional Commits; never AI attribution (`commit-msg.sh` enforces both).
- Commit as work lands, one logical chunk per commit, each green on the project's build gate. Push to the feature
  branch or the project's integration branch without asking, a worktree agent to its own branch; never push to a
  release or prod branch.
- A merge request is a release event, not a work-done event: suggest one only when a change is ready for another
  person to check on a shared stage, naming who checks what. Docs, TODO and tooling commits never trigger one.
A commit the device owner must act on or customise carries an `Action: <what to do>` line in its body.

## Review and device sync

- Every review ask runs `kit:review <MR<N>|target> [--answer|--fix|--only]`, never a free-form read of the diff;
  `kit:spec-review` for `spec.md`/`tasks.md`. On an MR, findings and answers are threads, chat gets the verdict.
- When the session context says "kit moved A..B", summarise `git log` and `git diff --stat` for the range, `Action`
  commits first. Apply nothing silently; run `plugin/scripts/kit-ack.sh` only after the user accepts.
