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
    '## Shape' 'One TypeScript app: logic in `src/`, the screen in `src/shelf-screen.ts`, tests in `test/`.' '' \
    '## Search surface' '`src/` and `test/`.' '' \
    '## Approval' 'The owner approves `spec.md` in chat; line 2 must be `<!-- approved: <YYYY-MM-DD> -->` before tasks.' '' \
    '## Tasks' 'Paths under `src/`; `Verify:` is `npm test -- <file>`; tests live in `test/` and find screen elements by visible text.' '' \
    '## UI design' 'none' '' \
    '## Loop' 'not used' '' \
    '## Commits' '`<type>: <description>`, one line.'

put src/lists.ts \
    'export function addBook(list: string[], title: string): string[] {' \
    '  return [...list, title];' \
    '}'

put src/shelf-screen.ts \
    'import { addBook } from "./lists";' '' \
    'export const ADD_LABEL = "Add book";' '' \
    'export function onAdd(list: string[], title: string): string[] {' \
    '  return addBook(list, title);' \
    '}'

put test/lists.test.ts \
    'import { addBook } from "../src/lists";' '' \
    'test("adds a title", () => {' \
    '  expect(addBook([], "Dune")).toEqual(["Dune"]);' \
    '});'

put test/shelf-screen.test.ts \
    'import { renderShelf } from "./render";' '' \
    'test("the add button is labelled", () => {' \
    '  expect(renderShelf().getByText("Add book")).toBeTruthy();' \
    '});'

body=(
    '# Shelf entries' ''
    '## Why' ''
    'A list holds only titles, so users cannot record who wrote a book. **Done when:** an entry stores a title and an'
    'author, and the button says what it adds to.' ''
    '## Scope' ''
    '**In:** an entry with title and author; the add button renamed.' ''
    '**Out:**' '- Cover images: no storage for files yet.' ''
    '## Rules' ''
    '- **BR-1** An entry is `{ title, author }`; both are 1 to 200 characters.'
    '- **BR-2** `addToShelf(list, entry)` replaces `addBook(list, title)`; `addBook` is deleted.' ''
    '## Stories' ''
    '**US-1 User adds a book with its author**'
    '- `addToShelf([], { title: "Dune", author: "Herbert" })` returns one entry with both fields.'
    '- An empty author throws `AUTHOR_REQUIRED`.'
    '- The add button reads "Add to shelf".'
)
put docs/specs/shelf-entries/spec.md "${body[@]}"
git add -A
git commit -q -m "docs: shelf entries spec"

reviewed=$(git rev-parse --short HEAD)
put docs/specs/shelf-entries/spec.md "<!-- reviewed: $reviewed -->" "<!-- approved: 2026-10-14 -->" "${body[@]}"
git commit -q -am "docs: seal and approve the shelf entries spec"
