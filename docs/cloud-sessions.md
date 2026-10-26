# Cloud sessions

A Claude Code cloud session runs one task on an Anthropic VM (4 vCPU, 16 GB RAM, 30 GB disk) and counts only against
the plan's usage limits, so parallel sessions spend those limits in parallel. Reference:
https://code.claude.com/docs/en/cloud-environments.

## What a project commits

- **A setup script** (`scripts/cloud-setup.sh`), run by the environment's setup field. Installs and image pulls only:
  the cache is a filesystem snapshot, so a started service is lost. It must exit 0 within about five minutes or
  nothing is cached, and environment variables are not set yet when it runs. Turn on the repo's git hooks here.
  The cache rebuilds only when the environment's own setup field or network level changes, never on a repo commit:
  every change to the script also edits a `# cache bump <date>: <why>` line in that field.
- **A SessionStart hook** that returns at once unless `CLAUDE_CODE_REMOTE=true`, and starts the services each
  session.
- **The project `CLAUDE.md`** carries every rule the session needs: `~/.claude`, this kit included, does not reach
  the VM unless the setup script clones it.
- **An owner doc** with the environment's field values, so the dialog never holds the only copy.

## Environment fields

- Network: Trusted; Custom only for a host a run proved blocked.
- Secrets: network secrets, never variables, which every user of the environment can read.
- Variables: dev-only values, plus `BASH_DEFAULT_TIMEOUT_MS`/`BASH_MAX_TIMEOUT_MS` when a gate outruns the 10-minute
  default cap.

## Briefing a session

- The VM clones the pushed branch: push first, or it starts from the default branch.
- One task per session with its done-check, split by files; sessions do not see each other, so merge in a set order.
- Commit as you go: an idle VM pauses and may be reclaimed with its uncommitted work.
- Data kept out of git (corpora, dumps) is absent; say so in the brief.
