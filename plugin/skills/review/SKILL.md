---
name: review
description: "Reviews code changes in any project and stack on three separate axes run as parallel subagents: Standards (the repo's rules, the stack and performance checklists, a smell baseline, comment hygiene), Spec (built what was asked, no more), Tests (do they protect anything). Precision over volume: every finding names a failing input, and a suggestion must be worth its cost. On a GitLab merge request it posts the findings as inline threads, optionally fixes them, answers each thread and posts an overview. Use for \"/kit:review\", \"review my branch\", \"review this PR\", \"review MR 12\", \"review since main\", \"review module X\", \"is this ready to merge\", \"answer the review comments on MR 12\", and after a kit:spec batch. Not for spec.md or tasks.md: that is kit:spec-review."
argument-hint: "[branch|HEAD|staged|MR<N>|PR<N>|<ref>|path:<glob>] [spec path] [--save] [--post] [--fix] [--answer]"
---

# Three-axis code review

You are finding what a senior reviewer on this team would block the merge for, and what would make the code
clearly better. AI reviews fail two ways: noise (a weak finding costs the author a round trip) and timidity (a
valuable change dropped because it is big). Zero findings is a legitimate result.

## 1. Pin the target

| Argument | Diff |
|---|---|
| omitted | `git diff <default>...HEAD` plus uncommitted changes; on the default branch, `HEAD` |
| `HEAD`, `staged`, `<ref>` | `git show HEAD`, `git diff --cached`, `git diff <ref>...HEAD` |
| `MR<N>` | the merge request's `diff_refs` through [mr-mode.md](references/mr-mode.md); `--post` is implied |
| `PR<N>` | `gh pr diff <N>` and `gh pr view <N> --json files,body` |
| `path:<glob>` | the files themselves, not a diff: every finding is pre-existing by definition |

Resolve the ref and check the diff is non-empty before spawning anything.

## 2. Gather sources

- **Always:** [value-vs-cost.md](references/value-vs-cost.md). In MR mode also [mr-mode.md](references/mr-mode.md).
- **Stack:** pick by changed paths and pass every match; load nothing else.

  | Changed | Reference |
  |---|---|
  | `*.kt`, `*.kts`, `*.java` | [jvm-spring.md](references/jvm-spring.md) |
  | `*.tsx`, `*.jsx`, `*.ts` under a React or Next app | [react-next.md](references/react-next.md) |
  | `*.go` | [go.md](references/go.md) |
  | migrations, `*.sql`, entities, repositories, queries | [sql.md](references/sql.md) |
  | auth, endpoints, input parsing, secrets, config, outbound HTTP | [security.md](references/security.md) |
  | I/O inside a loop, queries, caches, pools, threads or async, timeouts, list endpoints, renders | [performance.md](references/performance.md) |

- **Project:** root and nested `CLAUDE.md` on the touched paths, `.claude/rules/`, every file in `.claude/review/`
  (project-only checks; they override the stack reference), and `CONTRIBUTING.md` when present.
- **Spec:** the argument; else the spec directory matching the branch, per `.claude/spec/project.md` "Paths"; else
  issue refs in commits (`gh issue view`). None: ask once; "there is none" skips the Spec axis.
- **Gates:** what lint, hooks and CI already enforce (`no-slop.sh` owns comments and naming). Never a finding.

## 3. Run the axes in parallel

One message, three `sonnet` subagents, foreground. Each brief carries the diff command, the commit list, its source
paths, and the rules in sections 4 and 5. Each returns findings in the shape below, under 400 words, ending
`FINDINGS: <n>`.

- **Standards:** breaches of the project sources, then the stack and performance references, then the Fowler baseline
  (always judgement, silenced by any repo rule that endorses the pattern): Mysterious Name, Duplicated Code, Feature
  Envy, Data Clumps, Primitive Obsession, Repeated Switches, Shotgun Surgery, Divergent Change, Speculative
  Generality, Message Chains, Middle Man, Refused Bequest. Plus a forked utility where one exists, a one-caller class
  adding no abstraction, and:
  - **Comments:** only a non-obvious why, contract or trap; none that restate the code or a name, narrate steps, name
    a ticket, or claim what the code does not check; two lines at most; true without the diff (kit `CLAUDE.md`
    § Code owns the rules).
  - **Improvement lane:** boilerplate, copy-paste or an over-commented method is raised even when no rule names it, as
    a non-blocking suggestion with the concrete simpler form, per [value-vs-cost.md](references/value-vs-cost.md).
- **Spec:** a requirement or criterion missing or partial; behaviour nobody asked for; a criterion that looks done but
  is wrong. Quote the spec line each time.
- **Tests:** the four shapes in `rules/testing.md` by name; the stack reference's test section; a changed behaviour
  or criterion with no test; a test that stays green if its guarded line is deleted or inverted.

```
[P<0-3>] [hard|judgement] <verdict-style title, ≤80 chars>
<path:line> · <rule or spec line cited> · <input → what happens → what should happen> · fix: <bounded change>
```

## 4. Every finding passes all of these, or is deleted

1. **Failing input:** a concrete input, state or sequence; "might fail under load" is not one.
2. **Introduced here:** older problems go to Pre-existing as one-liners, unless the diff makes them worse.
3. **Not already handled:** the whole file and its callers were read, not just the hunk.
4. **Absence proven:** "missing", "duplicated" and "dead" state the grep and the count, searched by concept.
5. **Not taste:** two reasonable engineers would not disagree; with no written rule it is a P3 suggestion that names
   the simpler form, never a blocker.
6. **The fix works:** it compiles, keeps the contract, and passes the existing tests in your head; a library API you
   are unsure of is checked in context7 first.
7. **Bounded:** one specific change. A large one is sized (S/M/L) with a first step and a follow-up line, never
   deleted for size.
8. **Worth it:** value beats cost under [value-vs-cost.md](references/value-vs-cost.md); a suggestion that adds more
   than it removes needs a named failing case. Effort alone never drops a finding; the drop reason is written down.

**P0** exploit, data loss, broken build, live secret (stop and tell the user at once). **P1** a bug with a failing
input, race, broken contract, hot-path N+1, IDOR. **P2** rare edge, cold-path perf with an order-of-magnitude
estimate, test gap, doc drift. **P3** one-line nit or unruled suggestion, never blocks. More than two P0s means regrade.

## 5. Report

Per axis under its own heading, P0 to P3; never merge or rerank across axes, so one cannot mask another. Then
Pre-existing, then Coverage: files read fully, skimmed, skipped with a reason, and what was not run.

```
**Summary:** Standards <n> · Spec <n | skipped: no spec> · Tests <n>   (P0 <n> · P1 <n> · P2 <n> · P3 <n>)
**Worst per axis:** <one line each>
**Verdict:** ✅ approve / ⚠️ approve after P1s / ❌ request changes
```

`--save` also writes it to the project's review path, else `docs/reviews/<YYYY-MM-DD>-<target>.md`, never
overwriting one. With `--post` or `MR<N>`, the findings go to the merge request instead of chat (section 6). Fix
nothing unasked. On "fix" or `--fix`, with up to five P0/P1 findings fix them here, hard first, and rerun only the
touched axes; with more, post or save the report and print a fresh-session prompt that names it: re-read each file
first, one commit per finding, push back on wrong findings.

## 6. Merge request mode

`MR<N>` or `--post` on a GitLab remote: follow [mr-mode.md](references/mr-mode.md). One inline thread per finding
with the failing input and, for a small fix, a suggestion block; one summary note; with `--fix` a commit per
finding, a reply in each thread (`Fixed in <sha>` or `Declined: <reason>`), and a closing overview note. A later
review starts from the existing threads and never re-posts what is fixed or declined. `--answer` is the author's
side: answer another person's threads the same way.
