# `--loop`: every remaining batch, one landing

`/kit:spec implement <name> --loop` runs each remaining batch through the stages below, each agent in a fresh
context, then lands once. project.md "Loop" supplies the gate command, the test lock, any extra reviewer and any
extra briefing lines; if it says "not used", say so and stop.

## The orchestrator's role

You do not implement batches: you read `spec.md`, `tasks.md`, git, gate output and the subagents' reports, and
decide. Your context has to last the whole spec, so open a source file only for a fix you make yourself.

- **The briefing.** Each subagent starts with nothing but your prompt: the capability, the rules and traps that bite
  in this batch (quoted), what earlier batches decided, where the risk is and what done means.
- **Judgement on findings.** Every gate failure and reviewer finding gets fixed, except a finding that contradicts
  `spec.md`: it is dropped, and the drop and its reason go in the Session Log row.
- **Who fixes it.** A fix subagent costs about a batch. Fix it yourself when every finding of the round is mechanical
  and located: it names the file and the change, touches at most two files and about twenty lines, and needs no
  investigation. Otherwise one fix subagent takes the whole round, small findings included.

## Preconditions

Stop and name the missing step if any fails:

- `spec.md` and `tasks.md` both carry a `reviewed` seal, and `approved` when project.md "Approval" requires it.
- A `[UI]` spec has `## Chosen design` filled.
- You are in the spec's worktree on its branch, `git status --porcelain` is empty, and its dependencies are installed.
- The session can edit, build, test and commit without a permission prompt; the first prompt stalls an unwatched loop.

## Stages, per batch

For each batch with an unchecked criterion, in order. `BASE` is `HEAD` when the batch starts.

1. **Lock** the tests older than `BASE`, except the `Unlock:` paths, by project.md "Loop".
2. **Implement.** One subagent with the implement briefing.
3. **Verify on disk, not from the prose.** Tree clean; `HEAD` is the reported SHA and is new; every criterion of the
   batch is `[x]`; the Session Log has the batch's row.
4. **Independent tests.** A second subagent with the test briefing. It never saw the implementer's session, so its
   oracle can only come from the spec. After `PASS` verify as in stage 3; after `FAIL` the failing tests are the only
   uncommitted change.
5. **Gate and review, in parallel.** Only you run the gate (project.md "Loop"), in the background, while one
   subagent runs `kit:review <BASE>` with this spec, plus any extra reviewer project.md "Loop" names. A review with a
   P0 or P1 is `FAIL <n>`, one with neither is `PASS`, one that could not run is `BLOCKED <reason>`.
6. **Next batch** once every gate job and every verdict is `PASS`, after releasing the lock.

**Outcomes.**

- **`RESULT: STOP`** from the implementer: end the loop and give the owner the reason verbatim. Only the owner
  resolves a spec/code contradiction; once the spec is amended and resealed, `--loop` resumes.
- **A failure** (stage 3 mismatch, `TESTS: FAIL`, a failing gate job, a reviewer `FAIL`): judge a failing independent
  test against `spec.md` like any finding. Wait for every stage-5 result, then fix the round by "Who fixes it". The
  fix commits on top, keeps older tests locked, is never red, and runs the check that failed before committing. Then
  stage 5 again: the gate always, the reviewers only when the fix changed production logic or a test.
- **`RESULT: FAILED`:** save the patch to the scratch directory, `git reset --hard <BASE>`, and brief a fresh attempt
  with the error and the patch path.
- **A second failing round in one batch, or the same gate failing with the same cause in two batches:** stop and
  report both. Rounds you fixed yourself count.
- **A reviewer `BLOCKED`:** record it in the Session Log row and continue; the owner checks that batch by hand.

At most five subagent spawns per remaining batch.

## The implement briefing

Under 40 lines, in this order:

1. **Mission:** the capability in one sentence, the worktree, branch and `BASE`, and "invoke `kit:spec` and follow
   'One batch' to the letter".
2. **What matters here:** the rules and traps this batch's criteria cite, quoted; the Session Log decisions it depends
   on; the riskiest part and how a wrong approach would show. Never the whole spec.
3. **Done means:** the batch's criteria and `Verify:` line, quoted.
4. **Fixed constraints,** verbatim, plus project.md "Loop" additions:

```text
- Tests first by kit:tdd, one criterion at a time, each seen failing before its code. Commit them with the code
  that makes them pass; no commit is ever red.
- Solve the criterion for every valid input, not the tests' inputs: no branch, constant or lookup that exists to make
  a test pass. A second agent will test the batch with inputs you have not seen.
- Tests that existed before BASE are locked. One that fails means the code is wrong or the spec contradicts it.
- Do not push and do not run the full gate: the orchestrator runs it after you. Do not touch another batch's tasks.
  Never edit spec.md.
- Before your last commit, run in the foreground the batch's Verify line and the lint and type checks of every
  workspace you changed.
- In that last commit, tick the batch's criteria in tasks.md and append its Session Log row, with the decisions and
  blockers the next batch needs.
- If the batch contradicts the code, stop without committing further and report it.
- Reply in at most ten lines, ending with exactly one line:
  RESULT: DONE <head sha> | RESULT: STOP <one paragraph> | RESULT: FAILED <gate>: <first error line>
```

## The test briefing

The worktree, `BASE`, the batch's criteria and the rules they cite, quoted, then verbatim:

```text
You write independent tests for a batch another agent implemented. Your value is that you have not seen how it was
written, so keep it that way: read `git diff <BASE> --stat`, then only the public signatures, endpoints and DTOs the
batch added. Do not read method bodies or the implementer's tests.
- Per criterion, one test whose expected value is a literal from the criterion or rule, with inputs the criterion
  implies but its examples do not show.
- One test that drives the batch's criteria together through one realistic flow.
- Never change production code. A failing test stays failing and uncommitted: report the criterion, the expected
  value with its source, and the actual value. Commit only passing tests.
Reply in at most ten lines, ending with exactly one line: TESTS: PASS <head sha> | TESTS: FAIL <n>
```

## The fix briefing

The findings verbatim, each with what the reports say of its cause, then:

```text
Fix exactly these findings, nothing else, in new commits on top. Tests from before BASE stay locked. A finding you
believe is wrong: do not fix it, explain why in one line. Do not run the full gate; the orchestrator runs it after
you. Run the Verify line, lint and type checks in the foreground before committing.
Reply in at most ten lines, ending with RESULT: DONE <head sha> or RESULT: FAILED <gate>: <first error line>.
```

## After the last batch

1. **The full gate once** on the whole branch (project.md "Landing"). A failure: one fix subagent with the failing
   job's log, then the gate again. The same job failing twice: stop and report.
2. **Land** per project.md "Landing".
3. **Report:** batches done, commits, every verdict and how many fix rounds each batch needed, findings dropped and
   why, the gate result, and every failure-log row added.
