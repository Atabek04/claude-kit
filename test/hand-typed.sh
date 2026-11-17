#!/bin/bash
# shellcheck disable=SC2154
# Cases for plugin/scripts/hand-typed-gate.sh. Sourced by run.sh, which provides ROOT, WORK and the assert helpers.

hand_typed_case() {
    local want=$1 file=$2 out got
    out=$(jq -n --arg f "$file" '{tool_name: "Write", tool_input: {file_path: $f, content: "x"}}' |
        "$ROOT/plugin/scripts/hand-typed-gate.sh")
    got=allow
    [ -n "$out" ] && got=deny
    if [ "$got" = "$want" ]; then ok "hand-typed $want: $file"; else bad "hand-typed: $file" "want $want, got $got"; fi
}

run_hand_typed_cases() {
    local sandbox="$WORK/sandbox" plain="$WORK/plain"
    mkdir -p "$sandbox/src/main/kotlin" "$plain/src"
    : > "$sandbox/.hand-typed"
    hand_typed_case deny "$sandbox/src/main/kotlin/Sealed.kt"
    hand_typed_case deny "$sandbox/src/new/pkg/NotYetCreated.kt"
    hand_typed_case deny "$sandbox/build.gradle.kts"
    hand_typed_case allow "$sandbox/NOTES.md"
    hand_typed_case allow "$sandbox/.gitignore"
    hand_typed_case allow "$plain/src/Main.kt"
    hand_typed_case allow "$WORK/sandbox-sibling/Main.kt"
}
