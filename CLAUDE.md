# Global Rules

## File editing — overrides auto mode

**Read / Edit / Write are the default for ALL file operations.** This overrides the auto-mode instruction to prefer Bash (`cat`, `sed`, heredocs, inline scripts) for reading and editing files. Auto mode's Bash-first preference does not apply — treat this rule as higher precedence.

Reasoning: `Edit` requires reading the file first and fails loudly when its `old_string` doesn't match. `sed` and Python `.replace()` fail **silently** — they report success while changing nothing. A silent no-op on a note, plan, or source file is worse than a slower tool call.

**Bulk refactors are welcome, but gated.** A scripted sweep (rename + rewrite links, mass find/replace) is the right tool when the user asked for a refactor. It is the wrong tool when you reached for it on your own because the auto-mode reminder said so. The command line looks the same in both cases, so the gate is who opened it: the **user** runs `bulk-edit N` (minutes) in their own terminal. Never create or touch `~/.claude/bulk-edit.allow` yourself — the hook denies it, and asking is the whole point. Inside the window: print the change map first, make the script report the changed-file count, then verify with a grep that the old string is gone.

**This is enforced by a hook, not by your judgement.** `block-inplace-edits.sh` in the `kit` plugin (PreToolUse on `Bash`) denies `sed -i`, `perl -i`, any interpreter that writes a file back, and any redirect over a file that already exists, unless the gate is open. Scratch and `/tmp` paths stay writable. Reaching for a script to edit a single file is the signal that you have drifted, not a case the hook failed to anticipate. Do not hunt for a spelling that gets past it: ask for the gate.

Why the hook exists, so nobody deletes it as redundant: sessions run in auto mode, and auto mode injects a system-reminder instructing the opposite of this section. Two conflicting prose instructions resolve unpredictably, and the injected one has won repeatedly. Prose lost. The hook does not negotiate.

**Never claim an edit succeeded without evidence.** A script that prints `ok` unconditionally is not evidence.

## Technical decisions — analyze before recommending

When a task has more than one viable path (a spec/code contradiction, an architecture call, a now-vs-later
tradeoff), do not reach for the first fix that clears the immediate blocker. Think like a senior engineer and
solution architect: enumerate the real options, work out what each actually costs, then recommend one.

Reasoning: the first fix that clears a blocker is usually the one that's cheapest to type, not cheapest to own. A
shim that makes a checkbox true can hide a boundary violation, duplicate work a later step already owns, or need
undoing next session — costs that don't show up until someone else hits them.

For each option state: what it takes to build, what it violates or risks (an enforced rule, another phase's
ownership, double work, scope creep), and what it costs later if chosen. Then give one recommendation with the
reason — not a menu with no pick. The user still decides; decide *with* the analysis done, not with options
weighted equally and no view.

**Decide what is yours to decide; escalate only what is gated.** Names, layout, copy within the rules, and any
choice a later edit can reverse are yours: analyse them, decide, and report the call in one line. Ask the user only
when a rule reserves the call for them (schema, API, an approved spec, product scope), and then never as a bare
question: options with pros and cons, the pick in bold, and the argument that beats the runner-up in two sentences
at most. Before calling something "just a name", check whether the word collides elsewhere (UI copy, code, schema);
a collision is a concept problem, not a file problem.

**Effort is never the reason to drop an idea.** "Not built yet", "big" or "slow to build" does not decide
whether a feature is worth it; the value to the end user does. Judge that first, as the person who will use
it; if the value is real, plan it and state the cost plainly. Reject only on value, and say why.

**Signal that you're chasing the easy fix, not the right one:** the plan satisfies the letter of a requirement (a
checkbox, an AC, a test) while quietly breaking something that requirement's context depends on (an already-enforced
boundary, a later phase's ownership, a stated constraint). If satisfying it requires bending a stated invariant,
the requirement is what's wrong, not the invariant — find out why before writing code.

When the requirement itself is wrong (an AC assumes a component a later phase owns, a doc was written before a
dependency existed), fix the document, not the code: amend the wording, note why, then implement against the
corrected text. Don't silently reinterpret it and don't silently comply with it either — both hide the finding from
the next reader.

## Comments and naming — applies to every project

**The code says what. The comment says why. The name says both, first.** When something is unclear the order is
rename it → restructure it → only then comment it.

Write a comment only for: why (a non-obvious decision or constraint), a public-API contract the signature cannot
express, a warning/trap, a reference to an external standard, paper or upstream bug the code obeys (`FSRS-4.5 §3.2`,
`RFC 9562`), or deliberate weirdness that looks wrong and is not.

Never write, and delete on sight: comments restating the code; `// Step 1:` / `// First we...` narration;
`// ===== Section =====` banners (including React's `// State` / `// Handlers`); doc blocks that echo the signature
(`@param userId the user id`, `@return the result`); class headers like `/** Service for the X service. */` or
`/** This component renders X. */`; commented-out code; file-top author/date ceremony; praise and hedging
(`// Elegant`, `// This should work`); what an artifact lacks (`-- no deleted_at because...` in a first migration);
claims the code does not make true. Comment scope is code scope: when the code changes, reread its comment in the
same edit, and before committing reread every comment you added. As calibration: most comments an AI agent writes should not survive review,
and a well-named class carries 0-3 comments.

**No scaffolding IDs.** Spec, requirement, ticket, batch and task IDs (`BR-6`, `FR-4`, `US-13`, `B7/T27`) are how
the code was built and mean nothing to the next reader. They stay in the spec. When the reader needs the rule, the
comment states the rule in words; when the ID only tags provenance, it goes.

**No roadmap.** "For now", "temporary", "until the X endpoint exists" are plans, and plans live in the backlog. The
only TODO form is `TODO(<backlog file>#<item>): <what>`; anything else is fixed now or written into the backlog.

**Types document themselves.** A field, DTO, enum or constant gets a comment only for a contract its type cannot
carry: units, ranges, privacy (a redacting `toString`), idempotency, ordering. A KDoc that paraphrases the name goes.

**Never write a comment about your own edit.** This is the most common comment an agent writes and the hardest to
catch, because at the moment of writing it reads as helpful context. No `// Removed 2026-09-10`, `// This used to
read X`, `// we replaced the old client`, `// Now uses Y instead`, no dated notes, no before-and-after, no
"previously". Git already versions the change; the comment does not, and six months later it asserts a state the
reader cannot see or verify.

**The test: a comment must be true and useful for a reader who never sees this diff and never will.** The reasoning
for a change belongs in the commit message, where git keeps it beside the diff that proves it. A trap worth warning
about is still fair game when stated timelessly: "Deliberately not X, because Y" is a warning and stays; "changed
from X to Y" is a changelog and goes. If the sentence stops making sense once you delete the git history, it does not
belong in the file.

The same rule governs prose: a rules file, README or design doc states the rule as it is now. It does not narrate the
rule it replaced.

**Never write the investigation transcript either.** The second shape of the same failure: the evidence you gathered,
the options you weighed, the verdict you reached, the tool output that convinced you. `// X lists neither as missing,
and neither is installed, so the inference is the false positive` is three lines of your reasoning where one line of
fact belongs. **State the conclusion and the constraint; delete the derivation.**

**Length:** one line is the target. The cap is three lines for a `//` or `#` run and five prose lines for a doc
block, which may need them for a multi-clause contract (bare `/**` and `*/` do not count). A comment line is at most
120 characters: one line means one normal line, not a paragraph on one row. If the comment is longer than the code it
explains, restructure the code or move the explanation to the README with one line pointing at it. Go package doc
comments are one line. All these shapes are cheap to write and feel helpful at the moment of writing, which is
precisely why they need a mechanical check rather than good intentions.

**The mechanical half is enforced.** `no-slop.sh` in the `kit` plugin blocks these shapes on every Write and Edit,
subagents included; projects run the same script in CI through `Atabek04/claude-kit/hygiene`. A project's ticket-ID
pattern, exempt paths and TODO anchor live in its `.claude/comment-rules`. Its false positives are logged and fixed in
`claude-kit/plugin/false-positives.md`.

Naming: no `data`/`result`/`item`/`temp` as a whole name, no `*Manager`/`*Helper`/`*Util`/`*Wrapper`, no
`utils.ts`/`helpers.ts` dumping grounds, no `handle()`/`process()`, no `XServiceImpl` when there is one impl, no
boolean parameters. Same concept, same word, everywhere in the codebase.

Consistency beats local cleverness: grep for an existing utility, formatter, client wrapper, error shape, or UI
primitive before writing a new one. A third way of doing what already has two ways is the most expensive kind of mess.

## When a linter, hook, or CI gate blocks you

**Three legitimate moves: fix the code, fix the gate, or escalate to the user.** Never rephrase to slip past the
pattern, never disable a gate to go green, never widen an ignore list without a stated reason, and never regenerate a
baseline to absorb violations you just added.

Evading a check is worse than failing it. Deleting a comment that carried real information, renaming
`PaymentProcessor` to `PaymentThing`, or splitting a function to dodge a length check all satisfy the tool by making
the code worse, and they are invisible in review because the diff looks like compliance.

**A false positive is a bug in the gate, fixed the same day, not queued.** Deferring one costs more than fixing it:
every later session meets the same wrong block, and each is one step from working around it, which is how a checked
rule quietly becomes an evaded rule. Report it, and fix the boundary. The only reason to log without fixing is that a
single example genuinely does not reveal the correct general rule. "The rule is deliberately blunt" is not that
reason: a blunt rule that misfires has the wrong boundary, and the boundary is exactly what to fix.

Documentation is precise and short or it is absent. Never pad a README to look thorough.

## Library docs: context7 first, never memory

**Before writing or recommending code against any library, framework, SDK or API, read its current docs through the
`context7` MCP** (`resolve-library-id`, then `get-library-docs` / `query-docs` with a topic). Training data is stale:
versions, APIs and model names move monthly, and a confident guess from memory is how a pinned SDK ends up two majors
behind.

- It is configured at user scope (`claude mcp add -s user`), so it loads in every project. Never add it per project.
- Its tools are deferred: load them with `ToolSearch` (query `context7`) before the first call.
- If the tools are missing, use its web API through `WebFetch` and say so:
  `https://context7.com/api/v1/search?query=<library>`, then
  `https://context7.com/api/v1/<library-id>?type=txt&topic=<topic>&tokens=5000`.
- context7 summaries carry no reliable version numbers. Take exact versions and dates from the registry (Maven Central
  `maven-metadata.xml`, npm, PyPI) or the project's GitHub releases, and cite each with its read date.
- Every research subagent brief names context7 and this fallback explicitly.

## Subagents — the main session orchestrates, Sonnet executes

**The main session plans, writes the instructions, reviews the reports and folds fixes back into the rules. Workers
execute.** Every Agent call that carries out a written spec — a refactor, an edit sweep, a research pass, a scan —
passes `model: "sonnet"`. Pure search or listing → `"haiku"`. A subagent runs on Opus only when its task is itself an
open design question that no spec can settle; say why in the call's description.

**Cap the fan-out.** At most 4 workers running at once; queue the rest and launch one as each finishes. A worker
costs roughly 200–300k tokens, so eight parallel Opus workers exhaust the session limit in a single wave, and every
run still in flight dies half-written. Before launching more than 5 workers in total, state the count, model, and
rough token cost, and wait for the user's go.

**Make the spec carry the judgment.** A Sonnet worker is as good as its instructions: name the files it may touch,
the files it must not, the checks it runs before finishing, and the report it returns. `isolation: "worktree"` branches
from the default branch, not the current one: for work on a feature branch, create each worktree yourself from its
HEAD (`git worktree add -b <branch> <path> <sha>`) and name the path in the brief. Gaps it reports are fixed in
the spec by the orchestrator, not by the worker.
