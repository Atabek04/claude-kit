#!/bin/bash
set -euo pipefail

put() {
    local path=$1
    shift
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$@" > "$path"
}

git init -q
git config user.email eval@example.com
git config user.name eval

put .claude/spec/project.md \
    '# Shelf: spec context' '' \
    '## Paths' '`docs/specs/<name>/spec.md` and `tasks.md`.' '' \
    '## Search surface' '`src/` and `test/`.' '' \
    '## Approval' 'The owner approves `spec.md` in chat; line 2 must be `<!-- approved: <YYYY-MM-DD> -->` before tasks.' '' \
    '## Tasks' 'Paths under `src/`; `Verify:` is `npm test -- <file>`; tests live in `test/`.' '' \
    '## Loop' 'not used' '' \
    '## Commits' '`<type>: <description>`, one line.'

body=(
    '# Reading goal' ''
    '## Why' ''
    'Users add books but never finish them. **Done when:** a user can set a yearly goal of 1 to 365 books.' ''
    '## Rules' ''
    '- **BR-1** A goal is between 1 and 365 books.' ''
    '## Stories' ''
    '**US-1 User sets a yearly goal**'
    '- `POST /api/goals` with `{"books": 12}` from a signed-in user stores the goal and returns `201`.'
    '- A goal of 0 or 366 returns `400` with code `GOAL_OUT_OF_RANGE`.'
)
put docs/specs/reading-goal/spec.md "${body[@]}"
git add -A
git commit -q -m "docs: reading goal spec"

reviewed=$(git rev-parse --short HEAD)
put docs/specs/reading-goal/spec.md "<!-- reviewed: $reviewed -->" "${body[@]}"
git commit -q -am "docs: seal the reading goal spec"
