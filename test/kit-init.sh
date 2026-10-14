#!/bin/bash
# shellcheck disable=SC2154
# Cases for bin/kit-init. Sourced by run.sh, which provides ROOT, WORK, new_repo and the assert helpers.

KIT_INIT="$ROOT/bin/kit-init"
PINNED_SHA=0123456789abcdef0123456789abcdef01234567

kit_init() {
    KIT_INIT_OUT=$(env CLAUDE_KIT_SHA="$PINNED_SHA" "$KIT_INIT" "$@" 2>&1)
    KIT_INIT_STATUS=$?
}

tree_checksum() {
    (cd "$1" && find . -path ./.git -prune -o -type f -print | sort | xargs cat | cksum)
}

run_kit_init_cases() {
    local d="$WORK/init" before after lines
    new_repo "$d"
    printf '// Step 1: old debt\nval a = 1\n' > "$d/a.kt"
    git -C "$d" add -A
    git -C "$d" commit -q -m "feat: seed"

    kit_init "$d"
    assert_eq "kit-init: first run exits 0" "0" "$KIT_INIT_STATUS"
    assert_has "kit-init: first run reports creations" "$KIT_INIT_OUT" "created  .githooks/pre-commit"
    for f in .claude/comment-rules .githooks/pre-commit .githooks/commit-msg .github/workflows/hygiene.yml \
        .github/comment-debt-ceiling CLAUDE.md; do
        if [ -f "$d/$f" ]; then ok "kit-init: creates $f"; else bad "kit-init: creates $f" "missing"; fi
    done
    if [ -x "$d/.githooks/pre-commit" ] && [ -x "$d/.githooks/commit-msg" ]; then ok "kit-init: hooks are executable"; else bad "kit-init: hooks are executable" "not +x"; fi
    assert_eq "kit-init: sets core.hooksPath" ".githooks" "$(git -C "$d" config --local --get core.hooksPath)"
    assert_has "kit-init: workflow is pinned to the SHA" "$(cat "$d/.github/workflows/hygiene.yml")" "hygiene@$PINNED_SHA"
    assert_lacks "kit-init: workflow keeps no placeholder" "$(cat "$d/.github/workflows/hygiene.yml")" "__KIT_SHA__"
    assert_eq "kit-init: ceiling is the measured count" "1" "$(cat "$d/.github/comment-debt-ceiling")"
    lines=$(wc -l < "$d/CLAUDE.md" | tr -d ' ')
    if [ "$lines" -lt 30 ]; then ok "kit-init: CLAUDE.md skeleton is under 30 lines ($lines)"; else bad "kit-init: CLAUDE.md skeleton is under 30 lines" "$lines lines"; fi

    before=$(tree_checksum "$d")
    kit_init "$d"
    after=$(tree_checksum "$d")
    assert_eq "kit-init: second run changes nothing" "$before" "$after"
    assert_lacks "kit-init: second run creates nothing" "$KIT_INIT_OUT" "created"
    assert_has "kit-init: second run skips the hooks" "$KIT_INIT_OUT" "skipped  .githooks/pre-commit (exists)"

    kit_init "$d/.githooks"
    assert_eq "kit-init: a path inside the repo resolves to its root" "0" "$KIT_INIT_STATUS"
    assert_has "kit-init: the root is named" "$KIT_INIT_OUT" "kit-init: $d"

    local e="$WORK/init-existing"
    new_repo "$e"
    printf 'my own rules\n' > "$e/CLAUDE.md"
    mkdir -p "$e/.githooks"
    printf 'my hook\n' > "$e/.githooks/pre-commit"
    git -C "$e" config --local core.hooksPath custom-hooks
    kit_init "$e"
    assert_eq "kit-init: existing CLAUDE.md is kept" "my own rules" "$(cat "$e/CLAUDE.md")"
    assert_eq "kit-init: existing pre-commit is kept" "my hook" "$(cat "$e/.githooks/pre-commit")"
    assert_eq "kit-init: a different hooksPath is left alone" "custom-hooks" "$(git -C "$e" config --local --get core.hooksPath)"
    assert_has "kit-init: the foreign hooksPath is reported" "$KIT_INIT_OUT" "core.hooksPath (set to custom-hooks; left alone)"

    local outside
    outside=$(mktemp -d)
    kit_init "$outside"
    rmdir "$outside"
    assert_eq "kit-init: a directory outside git fails" "2" "$KIT_INIT_STATUS"

    run_kit_init_hook_cases "$d"
}

run_kit_init_hook_cases() {
    local d=$1 out
    printf 'val b = 2\n' > "$d/b.kt"
    git -C "$d" add b.kt
    out=$(cd "$d" && env CLAUDE_KIT="$ROOT" git commit -q -m "added b" 2>&1)
    if [ $? -ne 0 ]; then ok "kit-init hooks: a non-conventional subject is rejected by git"; else bad "kit-init hooks: a non-conventional subject is rejected by git" "$out"; fi
    out=$(cd "$d" && env CLAUDE_KIT="$ROOT" git commit -q -m "feat: add b" 2>&1)
    assert_eq "kit-init hooks: a conventional subject commits" "0" "$?"
    printf '// Step 1: new narration\nval c = 3\n' > "$d/c.kt"
    git -C "$d" add c.kt
    out=$(cd "$d" && env CLAUDE_KIT="$ROOT" git commit -q -m "feat: add c" 2>&1)
    if [ $? -ne 0 ]; then ok "kit-init hooks: pre-commit blocks added narration"; else bad "kit-init hooks: pre-commit blocks added narration" "$out"; fi
    git -C "$d" reset -q c.kt
    printf 'val d = 4\n' > "$d/d.kt"
    git -C "$d" add d.kt
    out=$(cd "$d" && env CLAUDE_KIT="$WORK/absent-kit" git commit -q -m "feat: add d" 2>&1)
    assert_eq "kit-init hooks: a missing kit clone warns and passes" "0" "$?"
    assert_has "kit-init hooks: the warning names the missing gate" "$out" "not found"
}
