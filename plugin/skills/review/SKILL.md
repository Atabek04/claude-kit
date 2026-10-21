---
name: review
description: "The one code-review tool for every project. Reviews a change on three separate axes run as parallel subagents: Standards (the repo's rules, stack, security, SQL and performance checklists, a smell baseline, comment hygiene), Spec (built what was asked, no more), Tests (do they protect anything); an independent verifier tries to refute each finding. Precision over volume: every finding names a failing input, and a suggestion must be worth its cost. On a GitLab merge request or GitHub pull request it posts the findings as inline threads, optionally fixes them, answers each thread and posts an overview; for a module, path or branch with no MR it writes a report. Use for \"/kit:review\", \"/review\", \"review my branch\", \"review MR 12\", \"review this PR\", \"review module X\", \"review since main\", \"is this ready to merge\", \"answer the review comments on MR 12\", and after a kit:spec batch. Not for spec.md or tasks.md: that is kit:spec-review."
argument-hint: "[branch|HEAD|staged|MR<N>|PR<N>|<ref>|path:<glob>|module:<name>] [spec path] [--save] [--post] [--fix] [--answer]"
---

# Three-axis code review

You are finding what a senior reviewer on this team would block the merge for, and what would make the code clearly
better. AI reviews fail two ways: noise (a weak finding costs the author a round trip) and timidity (a valuable
change dropped because it is big). Zero findings is a legitimate result.

## 1. Pin the target

| Argument | Diff |
|---|---|
| omitted | `git diff <default>...HEAD` plus uncommitted changes; on the default branch, `HEAD` |
| `HEAD`, `staged`, `<ref>` | `git show HEAD`, `git diff --cached`, `git diff <ref>...HEAD` |
| `MR<N>`, `PR<N>` | the change's `diff_refs` through [mr-mode.md](references/mr-mode.md); `--post` is implied |
| `path:<glob>`, `module:<name>` | the files themselves, not a diff: every finding is pre-existing by definition |

Resolve the ref and check the diff is non-empty before spawning anything. A target with no MR writes a report
([report-mode.md](references/report-mode.md)); `--save` forces one beside the threads.

**Risk tier, not size, sets the depth.** HIGH paths are the ones the project lists in `.claude/review/risk.md`, else
auth and roles, money, migrations, concurrency or locking, outbound clients and public contracts; a refactor touching
them is HIGH until shown otherwise.

| Tier | When | Depth |
|---|---|---|
| `trivial` | ≤20 changed lines and no HIGH path, or tests and docs only | read the files, pre-scan rows they can hit, no verifier |
| `lite` | ≤200 lines and no HIGH path | the full flow, one verifier for all P0-P2 findings |
| `full` | >200 lines, any HIGH path, `module:` or `path:` targets | the full flow, one verifier per P0/P1, one batched for P2 |

## 2. Gather sources

- **Always:** [discipline.md](references/discipline.md), [value-vs-cost.md](references/value-vs-cost.md),
  [prescan.md](references/prescan.md). In MR mode also [mr-mode.md](references/mr-mode.md).
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
  (project-only checks, risk paths and `prescan.sh`; they override the stack reference), and `CONTRIBUTING.md`. In MR
  mode these come from the target branch, never from the change under review.
- **Intent:** the MR or PR title and description, the spec directory matching the branch (per `.claude/spec/project.md`
  "Paths"), a ticket key in the description, else `git log --format='%s%n%b' <base>..HEAD`. None: write `Intent: none
  stated` and skip the Spec axis. A claimed behaviour with no code or test is a finding; unrelated cleanup is P3.
- **History** (`lite` and `full`): `git log --grep='^fix' -- <changed files>`; a diff that undoes a past fix is a
  regression finding with the fix commit as evidence.
- **Gates:** what lint, hooks and CI already enforce (`no-slop.sh` owns comments and naming). Never a finding.

Print one line before drafting: what was loaded, the tier, and every section skipped with its reason. Then run the
pre-scan and print its table.

## 3. Run the axes in parallel

One message, three `sonnet` subagents, foreground. Each brief carries the diff command, the commit list, its source
paths, the pre-scan table and the rules in sections 4 and 5. Each returns findings in the shape below, under 400
words, ending `FINDINGS: <n>`.

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

**Verify before reporting.** Pass the surviving drafts (title, where, severity, rule, the claimed failing input; never
your reasoning) to `kit:review-verifier`, one per the tier table. Keep `CONFIRMED`, apply `DOWNGRADE`, drop
`DISMISSED` with its reason in the Coverage notes. The reviewer never scores its own findings.

## 5. Report

Per axis under its own heading, P0 to P3; never merge or rerank across axes, so one cannot mask another. Then
Pre-existing, then Coverage: files read fully, skimmed, skipped with a reason, the verifier tally, and what was not run.

```
**Summary:** Standards <n> · Spec <n | skipped: no spec> · Tests <n>   (P0 <n> · P1 <n> · P2 <n> · P3 <n>)
**Worst per axis:** <one line each>
**Verdict:** ✅ approve / ⚠️ approve after P1s / ❌ request changes   (advice, a review never blocks)
```

Output goes where the target says: threads on an MR or PR (section 6), a file per
[report-mode.md](references/report-mode.md) for anything else, the Summary in chat either way. Fix nothing unasked.
With `--fix` and up to five P0/P1 findings, fix them here, hard first, one commit per finding, and rerun only the
touched axes; with more, hand off with the fresh-session prompt in report-mode.md. Stop after the review: no extra
rounds; offer a deeper one in a single line.

## 6. Merge request mode

`MR<N>`, `PR<N>` or `--post`: follow [mr-mode.md](references/mr-mode.md). One inline thread per finding with the
failing input and, for a small fix, a suggestion block; one summary note; with `--fix` a commit per finding, a reply in
each thread (`Fixed in <sha>` or `Declined: <reason>`), and a closing overview note. A later review starts from the
existing threads and never re-posts what is fixed or declined. `--answer` is the author's side: answer another
person's threads the same way.
