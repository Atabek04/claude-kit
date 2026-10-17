---
name: debug
description: "Diagnoses a bug or performance regression in any stack by building a command that goes red on the exact symptom before forming any theory, then ranked falsifiable hypotheses, one-variable probes, a regression test before the fix, and cleanup. Use for \"/kit:debug\", \"debug this\", \"diagnose\", \"why is this failing\", \"this is broken\", \"it throws\", \"flaky test\", \"it got slow\", or any pasted stack trace or wrong output."
argument-hint: "<symptom, error or failing command>"
---

# Diagnose, then fix

The failure this prevents is reading code to build a theory before anything can show the bug. With a tight red
signal the cause falls out; without one, no amount of reading finds it.

Read first: the stack reference for the touched paths ([jvm.md](references/jvm.md), [web.md](references/web.md),
[go.md](references/go.md)), then every file in the project's `.claude/debug/` (ports, caches, seeds, tools; they
override the reference).

**Redact** every secret in commands and output you show (`<REDACTED>`); build loops on env vars, and quote only the
lines of a captured artifact that carry the signal.

## 1. Build the loop

Try in order, stopping at the first that reaches the bug: a failing test at the seam that reaches it; an HTTP call
against the running app; a CLI run on a fixture diffed against known-good output; a browser script asserting DOM,
console or network; a captured request or event replayed in isolation; a throwaway harness of the smallest subset;
a property or fuzz loop for "sometimes wrong"; `git bisect run` between a good and a bad state; the same input
through old and new versions, diffed.

Then tighten it: faster (narrow scope, skip setup), sharper (assert the symptom, not "did not crash"), deterministic
(pin the clock, seed randomness, isolate files and network). A flaky bug needs a higher reproduction rate, not a
clean repro: repeat, parallelise, stress, until it fails often enough to debug.

**Done when** you have run one command, shown its redacted output, and it is red on the user's exact symptom,
deterministic (or at a pinned rate), seconds fast, and runnable without a human. No such command: stop, list what
you tried, and ask for an environment that reproduces it, a captured artifact, or leave to add temporary
instrumentation. **No red command, no step 2.**

## 2. Reproduce and minimise

Confirm it is the user's failure, not a neighbour, and record the exact symptom. Cut inputs, callers, config, data
and steps one at a time, rerunning after each, until every remaining element is load-bearing.

## 3. Hypothesise

Write 3 to 5 ranked hypotheses before testing any, each falsifiable: "if X is the cause, changing Y makes it vanish".
No stated prediction, no hypothesis. Show the list to the user (they may know which was just deployed or already
ruled out) and proceed with your ranking if they are away.

## 4. Probe

Each probe tests one prediction and changes one variable. A debugger or REPL first, then logs at the boundaries that
separate hypotheses, never log-everything-and-grep. Tag every temporary log `[DEBUG-<4 hex>]`. Performance: measure a
baseline (profiler, timer, query plan) and bisect; logs mislead there.

## 5. Fix with a regression test

Turn the minimised repro into a failing test at a seam that reproduces the real call pattern, with a literal expected
value (`rules/testing.md`), and watch it fail first. No such seam: say so; that is a design finding, not permission
to test a shallower seam. Fix the cause, never the test's input. Watch it pass, then rerun the step 1 loop on the
original, un-minimised scenario.

## 6. Clean up

Done only when: the original loop is green; the regression test passes or its missing seam is reported; a grep for
`[DEBUG-` finds nothing; throwaway harnesses are deleted; and the commit message (`fix(<scope>): …`) states the cause
that proved true, so the next debugger learns it.
