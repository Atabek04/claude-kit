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

put README.md '# Shelf' '' 'A reading list: users keep a list of books they want to read.'

put docs/specs/reading-goal/spec.md \
    '# Reading goal' '' \
    '## Why' '' \
    'Users add books but never finish them. **Done when:** a user can set a yearly goal.' '' \
    '## Rules' '' \
    '- **BR-1** A goal is between 1 and 365 books.' '' \
    '## Stories' '' \
    '**US-1 User sets a yearly goal**' \
    '- The goal screen works correctly.'

git add -A
git commit -q -m "docs: reading goal spec"
