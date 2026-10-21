# claude-kit

**One source of rules, skills, hooks and CI gates for Claude Code, on every machine and in every project.**

Rules that a script can check are hooks. Everything else is short prose that loads only when it applies.

## What's inside

| | Loads | Contents |
|---|---|---|
| [`CLAUDE.md`](CLAUDE.md) | every session | principles for all projects |
| [`rules/`](rules) | when a matching file is touched | `jvm` · `go` · `python` · `typescript` · `testing` · `docs` · `instructions` |
| [`plugin/skills/`](plugin/skills) | on `/kit:<name>` or a matching request | below |
| [`plugin/hooks/`](plugin/hooks/hooks.json) | every tool call | comment and naming gate, scripted-edit gate, startup sync |
| [`hygiene/`](hygiene/action.yml) | CI | the comment gate on PR diffs or the whole tree |

**Skills**

| Build | Check | Learn |
|---|---|---|
| `spec` · `spec-write` · `spec-tasks` | `review` · `spec-review` | `teach` · `math-professor` |
| `tdd` · `debug` · `frontend-design` · `mr-description` | | `self-mastery-coach` |

Personal settings for the learning skills live in `~/.claude/learner.md`, outside the kit.

## Install

```bash
gh repo clone Atabek04/claude-kit ~/claude-kit && ~/claude-kit/install.sh
```

Safe to re-run; `install.sh --check` only reports. It imports `CLAUDE.md` into `~/.claude/CLAUDE.md`, links `rules/`,
installs the `kit` plugin with auto-update, and sources `bulk-edit` in `~/.zshrc`. Needs bash 3.2+, `jq`, `git`, `awk`.

New project: `bin/kit-init <path>` scaffolds the git hooks, the hygiene workflow and a `CLAUDE.md` skeleton.

## In a project

- The kit `CLAUDE.md` and matching `rules/` are already loaded; never copy them into a project file.
- A project's `CLAUDE.md`, `.claude/rules/`, `.claude/review/` and `.claude/debug/` hold only what is true of that
  project, and win on conflict.
- A lesson for every project ends a report as `Kit: <rule> -> <file>`, applied only after the user says yes.

## Changing the kit

1. `git -C ~/claude-kit pull --rebase`.
2. Put the change where it loads only when needed ([`rules/instructions.md`](rules/instructions.md)); one owner per
   fact.
3. A gate change gets an allow and a deny case. Run `bash test/run.sh` and `scripts/check-publishable.sh`.
4. Commit (Conventional Commits) and push. Every push is a new plugin version, picked up at the next launch; projects
   pinning the CI action bump its SHA.
5. Everything must be safe to publish: no secrets, no employer or client names, no home paths.
6. A change that needs a per-device step (re-run `install.sh`, a local setting, a hook to review) gets an
   `Action: <what to do>` line in the commit body.

## Syncing devices

Each device keeps `~/.claude/kit-seen`, the kit commit it last reviewed (first run records HEAD silently). At session
start `sync-kit.sh` pulls, then compares it with HEAD and reports `kit moved A..B, N commits, M Action` plus the first
`Action:` lines. Claude summarises the range; after you accept, `plugin/scripts/kit-ack.sh` moves the checkpoint.
A checkpoint that is not an ancestor of HEAD (rewritten history) is reported the same way. Device-only facts stay in
the private `~/.claude/CLAUDE.md`.

How the gates work, and what to do when one misfires: [`docs/gates.md`](docs/gates.md).
