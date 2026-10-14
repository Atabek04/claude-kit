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
    '## Paths' '`docs/specs/<name>/spec.md` and `tasks.md`. Failure log: `.claude/spec/failure-log.md`.' '' \
    '## Owners' 'Product and stack: `README.md`.' '' \
    '## Shape' 'One TypeScript service in `src/` with an HTTP API under `/api`; tests in `test/`, run by `npm test`.' '' \
    '## Search surface' '`src/` and `test/`.' '' \
    '## Approval' 'The owner approves `spec.md` in chat; line 2 is `<!-- approved: <YYYY-MM-DD> -->` before tasks.' '' \
    '## Spec rules' 'none' '' \
    '## Review checks' '- [ ] Every new endpoint states who may call it.' '' \
    '## Tasks' 'Paths under `src/`; `Verify:` is `npm test -- <file>`; tests live in `test/`.' '' \
    '## UI design' 'none' '' \
    '## Branch and worktree' 'The current checkout.' '' \
    '## Implementation' 'none' '' \
    '## Gate' '`npm test`.' '' \
    '## Loop' 'not used' '' \
    '## Commits' '`<type>: <description>`, one line.' '' \
    '## Landing' '`npm test`, then the owner merges.'

put README.md '# Shelf' '' 'A reading list: users keep a list of books they want to read.'

put src/lists.ts \
    'export const MAX_BOOKS = 200;' '' \
    'export function addBook(list: string[], title: string): string[] {' \
    '  if (list.length >= MAX_BOOKS) throw new Error("LIST_FULL");' \
    '  return [...list, title];' \
    '}'

put test/lists.test.ts \
    'import { addBook } from "../src/lists";' '' \
    'test("adds a title", () => {' \
    '  expect(addBook([], "Dune")).toEqual(["Dune"]);' \
    '});'

put docs/specs/reading-goal/spec.md \
    '# Reading goal' '' \
    '**Backlog:** README.md#goals · **UI:** none · **Touches:** src/lists.ts, a new goals endpoint' '' \
    '## Why' '' \
    'Users add books but never finish them; 80% of lists have no book marked read. **Done when:** a user can set a' \
    'yearly goal and see how many books are left.' '' \
    '## Scope' '' \
    '**In:** a yearly goal per user and the count of books left.' '' \
    '**Out:**' '- Sharing goals' '' \
    '## Rules' '' \
    '- **BR-1** A goal is between 1 and 365 books.' '' \
    '## Stories' '' \
    '**US-1 User sets a yearly goal**' \
    '- `POST /api/goals` with `{"books": 12}` stores the goal and returns `201`.' \
    '- A goal of 0 or 366 returns `400` with code `GOAL_OUT_OF_RANGE`.' \
    '- The goal screen works correctly.' '' \
    '## Changes' '' \
    '| Kind | What | Note |' '|---|---|---|' \
    '| Endpoint, new | `POST /api/goals` | body `{"books": number}`, returns `201` |' '' \
    '## Traps' '' \
    '- **`src/lists.ts:4` already caps a list at 50 books,** so a goal above 50 can never be met; BR-1 must cap at 50.'

git add -A
git commit -q -m "docs: reading goal spec"
