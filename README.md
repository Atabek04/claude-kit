# claude-kit

The single source of Claude Code rules, skills, agents, hooks and CI gates for every project and machine.
Mechanical rules are hooks; the rest is short prose that loads only when it applies.

## Layout: what loads when

| Path | Loads | What |
|---|---|---|
| `CLAUDE.md` | every session (imported by `~/.claude/CLAUDE.md`) | principles for all projects, under 100 lines |
| `rules/*.md` | when a file matching its `paths:` is touched (`~/.claude/rules/kit` links here) | one stack or topic each: `jvm`, `go`, `python`, `typescript`, `testing`, `docs`, `instructions` |
| `plugin/skills/` | description always, body on invoke (`/kit:<name>`) | procedures: `spec`, `spec-write`, `spec-review`, `spec-tasks`, `review`, `debug`, `tdd`, `teach`, `frontend-design`, `self-mastery-coach` |
| `plugin/hooks/hooks.json` | every tool call | `no-slop.sh` (comments, naming), `block-inplace-edits.sh` (scripted edits), `sync-kit.sh` (pulls this clone at startup) |
| `plugin/scripts/commit-msg.sh` | git commit, via a project's `.githooks/commit-msg` | Conventional Commits, no AI attribution |
| `hygiene/action.yml` | CI, pinned by SHA | the comment gate on PR diffs and the whole tree |
| `bin/kit-init`, `templates/project/` | once per project | scaffolds the gates and a `CLAUDE.md` skeleton |
| `plugin/false-positives.md` | when a gate misfires | the log of gate fixes |

## For agents in any project

- The kit `CLAUDE.md` and matching `rules/` are already in your context; do not copy them into a project file.
- A project's `CLAUDE.md` and `.claude/rules/` add only what is true of that project, and win on conflict.
- Project gate settings live in `.claude/comment-rules`; spec settings in `.claude/spec/project.md`.
- When a lesson would help every project, end your report with `Kit: <rule> -> <file>`. Change the kit only after
  the user says yes.

## Changing the kit

1. `git -C ~/claude-kit pull --rebase`.
2. Put the change where it loads only when needed (`rules/instructions.md` says where); one owner per fact.
3. A gate change gets an allow and a deny case; run `bash test/run.sh` and `scripts/check-publishable.sh`.
4. Commit (Conventional Commits), push, then `claude plugin marketplace update claude-kit && claude plugin update
   kit@claude-kit` (new hooks load next session); projects that pin the CI action bump their SHA to take the change.
5. Everything must be safe to publish: no secrets, employer or client names, or home paths.

## Install on a new machine

```bash
gh repo clone Atabek04/claude-kit ~/claude-kit && ~/claude-kit/install.sh
```

`./install.sh --check` changes nothing and reports each step as ok, todo or warn (exit 1 when a step is todo). Re-running
`./install.sh` is safe: it only does what is missing.

1. Clones the kit to `~/claude-kit` (`$CLAUDE_KIT`), where projects' hooks also find `no-slop.sh` and `commit-msg.sh`.
2. Puts `@~/claude-kit/CLAUDE.md` at the top of `~/.claude/CLAUDE.md`, keeping anything else that machine needs.
3. Links `~/.claude/rules/kit` to `~/claude-kit/rules`.
4. Adds the marketplace, installs `kit@claude-kit`, and turns on its auto-update in `~/.claude/settings.json`.
5. Sources `shell/bulk-edit.zsh` from `~/.zshrc` and hints `gh auth setup-git` when the private repository is out of reach.

New project: `bin/kit-init <path>` scaffolds the comment rules, git hooks, hygiene workflow and a `CLAUDE.md` skeleton.

The plugin has no `version`, so every pushed commit is a new version; auto-update fetches it at the next launch.
Remove any `block-inplace-edits.sh` entry from `~/.claude/settings.json`, or the hook runs twice.
Requirements: bash 3.2 or newer, `jq`, `git`, `awk` (BSD, GNU or mawk).

## The comment-hygiene gate

`no-slop.sh` enforces the "Comments and naming" rules from the global `CLAUDE.md` mechanically.

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
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- uses: Atabek04/claude-kit/hygiene@main
  with:
    mode: diff
```

The checkout needs `fetch-depth: 0` so `<base>...HEAD` has a merge base. `mode: tree` takes `ceiling`.

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
