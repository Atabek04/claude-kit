# Gates

How the kit's hooks and CI gates work. The rules they enforce are in the kit `CLAUDE.md`.

## Why hooks instead of prose

Sessions run in auto mode, and auto mode injects a system reminder that tells the model to edit files with `sed`, heredocs
and short scripts. The global `CLAUDE.md` says the opposite and claims precedence, but two conflicting prose instructions
resolve unpredictably, and the injected one has won repeatedly. A hook does not negotiate.

A bug and a deliberate bulk refactor look identical on the command line, so `block-inplace-edits.sh` gates on who opened
the window: the user runs `bulk-edit N` in their own terminal, which writes an expiry epoch to `~/.claude/bulk-edit.allow`.
While it is in the future, scripted edits pass. Any Bash command that names the gate file is denied, so the agent cannot
open it for itself. Scratch paths stay writable.

The comment rules have the same problem. They are in the global rules, and a model under pressure to finish writes
`// Step 1:` anyway. The gate makes the cheap path the correct one.

## The comment-hygiene gate

`no-slop.sh` enforces the "Code" comment and naming rules from the kit `CLAUDE.md` mechanically.

| Mode | Use |
|---|---|
| no arguments | PreToolUse hook on Write, Edit and MultiEdit. Reads the event on stdin and denies with the violations and the false-positive escape text |
| `--diff <base>` | Checks lines added in `<base>...HEAD`. `--staged` adds the index. Exit 1 on any violation |
| `--tree [--ceiling N]` | Checks every tracked file. With a ceiling: exit 1 above it, and a note to lower it when the count has fallen |

A deny is printed as JSON on stdout with exit 0, the form the hooks documentation names for structured control:
"Exit 0 means success, and is the intended exit code when you print JSON for structured control."

Hook mode judges only lines the edit adds. A line carried over verbatim from `old_string` (or from the file on disk, for a
Write over an existing file) is inherited debt and never blocks; a line the edit touches is new text and does.
A run-cap violation counts when its run contains an added line.

### Rules

`step-narration`, `banner`, `section-label`, `signature-echo`, `todo-anchor`, `run-cap` (3 lines of `//` `#` `--`, 5 in a
block or docstring), `width` (120 characters), `changelog`, `roadmap`, `commented-out-code`, `ticket-id`
(config only), `go-package-doc`, `banned-name`. Markdown runs only `changelog`. `hint_for` in the script gives the fix for each.

### Per-project config

`<root>/.claude/comment-rules`, `key=value` lines, `#` comments. Parsed with sed, never sourced.

```
ticket_regex=\b(BR|PL)-[0-9]+\b
exempt=docs/specs/* corpus/**
todo_anchor=docs/backlog/
```

`exempt` globs are relative to the root; `**` means `*`. `todo_anchor` makes `TODO(docs/backlog/<file>.md#<item>): <what>`
the only allowed form. Always exempt: any `CLAUDE.md`, and in this repo the script itself, `plugin/false-positives.md`
and `test/fixtures/`.
For experiments, `--config <file>` or `NO_SLOP_CONFIG` replaces the config file.

### CI

```yaml
- uses: actions/checkout@<sha>
  with:
    fetch-depth: 0
- uses: Atabek04/claude-kit/hygiene@<sha>
  with:
    mode: diff
```

Pin both by SHA. The checkout needs `fetch-depth: 0` so `<base>...HEAD` has a merge base. `mode: tree` takes `ceiling`.

## False positives

A false positive is a bug in the gate and is fixed the same day, not queued. Three moves are legitimate when the gate
fires: fix the code, fix the gate, or tell the user. Rephrasing around the pattern is not one of them, and neither is
disabling the hook.

To fix the gate: narrow the pattern in `no-slop.sh` until it stops misfiring without losing the case it was written for,
add an allow and a deny case to `test/fixtures/cases.txt`, and add a row to `plugin/false-positives.md` saying what was
done.

## Tests

```bash
bash test/run.sh
```

Runs the cases through the real hook entry point (`#!/bin/bash`, so macOS bash 3.2), then `--tree` and `--diff` against
throwaway repos. CI also runs `shellcheck -S warning` and `actionlint`.
