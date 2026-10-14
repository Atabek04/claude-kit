#!/bin/bash
# Test suite for the plugin's hook scripts. Needs bash, jq, git. no-slop.sh cases live in test/fixtures/cases.txt.
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GATE="$ROOT/plugin/scripts/no-slop.sh"
CASES="$ROOT/test/fixtures/cases.txt"
WORK=$(mktemp -d "$ROOT/test/.work.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/proj"
PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$1"
}

bad() {
    FAIL=$((FAIL + 1))
    printf 'FAIL %s: %s\n' "$1" "$2"
}

assert_eq() {
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "wanted '$2', got '$3'"; fi
}

assert_has() {
    case $2 in
        *"$3"*) ok "$1" ;;
        *) bad "$1" "output lacks '$3': $2" ;;
    esac
}

assert_lacks() {
    case $2 in
        *"$3"*) bad "$1" "output contains '$3': $2" ;;
        *) ok "$1" ;;
    esac
}

decision() {
    case $1 in
        *'"permissionDecision": "deny"'*) echo deny ;;
        *) echo allow ;;
    esac
}

judge() {
    local name=$1 expect=$2 out=$3 want rule="" got
    want=${expect%%:*}
    case $expect in *:*) rule=${expect#*:} ;; esac
    got=$(decision "$out")
    if [ "$got" != "$want" ]; then
        bad "$name" "expected $want, got $got $(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' | sed -n '2,4p' | tr '\n' ' ')"
        return
    fi
    if [ "$want" = deny ] && [ -n "$rule" ]; then
        case $out in
            *"- $rule: "*) ok "$name" ;;
            *) bad "$name" "denied, but not for $rule" ;;
        esac
        return
    fi
    ok "$name"
}

event_write() {
    jq -n --arg p "$1" --rawfile c "$2" '{tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}

event_edit() {
    jq -n --arg p "$1" --rawfile o "$2" --rawfile n "$3" \
        '{tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n}}'
}

new_repo() {
    rm -rf "$1"
    mkdir -p "$1"
    git -C "$1" init -q
    git -C "$1" checkout -q -b main
    git -C "$1" config user.email test@example.com
    git -C "$1" config user.name test
    git -C "$1" config commit.gpgsign false
}

set_config() {
    mkdir -p "$PROJ/.claude"
    case $1 in
        ticket)
            printf '%s\n' '# test config' \
                'ticket_regex=\b(BR|PL|H|S|G|E|FR|US|AC|OQ|SF|NFR)-[0-9]+[a-z]?\b|\bD[0-9]{1,2}\b|\bB[0-9]+/T[0-9]+\b|\bT[0-9]{1,3}\b' \
                'exempt=docs/specs/* corpus/**' > "$PROJ/.claude/comment-rules"
            ;;
        anchor) printf '%s\n' 'todo_anchor=docs/backlog/' > "$PROJ/.claude/comment-rules" ;;
        *) rm -f "$PROJ/.claude/comment-rules" ;;
    esac
}

trim_field() {
    local v=$1
    v=${v#"${v%%[![:space:]]*}"}
    v=${v%"${v##*[![:space:]]}"}
    printf '%s' "$v"
}

split_cases() {
    awk -v dir="$WORK/cases" '
        /^=== / {
            if (out != "") close(out)
            n++
            print substr($0, 5) > (dir "/" n ".meta")
            close(dir "/" n ".meta")
            out = dir "/" n ".old"
            printf "" > out
            next
        }
        /^--- new ---$/ { close(out); out = dir "/" n ".new"; printf "" > out; next }
        { print > out }
        END { print n > (dir "/count") }
    ' "$CASES"
}

run_case_file() {
    local i=$1 meta name rel kind cfg expect path out
    meta=$(cat "$WORK/cases/$i.meta")
    IFS='|' read -r name rel kind cfg <<< "$meta"
    name=$(trim_field "$name")
    case $name in *"${ONLY:-}"*) ;; *) return 0 ;; esac
    rel=$(trim_field "$rel")
    kind=$(trim_field "$kind")
    cfg=$(trim_field "${cfg:-}")
    rel=${rel//\$HOME/$HOME}
    set_config "$cfg"
    case $rel in
        /*) path=$rel ;;
        *) path="$PROJ/$rel"; mkdir -p "$(dirname "$path")" ;;
    esac
    case $kind in
        edit:*)
            expect=${kind#edit:}
            out=$(event_edit "$path" "$WORK/cases/$i.old" "$WORK/cases/$i.new" | "$GATE")
            ;;
        over:*)
            expect=${kind#over:}
            cp "$WORK/cases/$i.old" "$path"
            out=$(event_write "$path" "$WORK/cases/$i.new" | "$GATE")
            rm -f "$path"
            ;;
        *)
            expect=$kind
            out=$(event_write "$path" "$WORK/cases/$i.old" | "$GATE")
            ;;
    esac
    judge "$name" "$expect" "$out"
}

gen_text() {
    local unit=$1 count=$2 out="" i=0
    while [ "$i" -lt "$count" ]; do
        out="$out$unit"
        i=$((i + 1))
    done
    printf '%s' "$out"
}

width_case() {
    local name=$1 expect=$2 unit=$3 count=$4 file="$WORK/width.kt"
    printf '// %s\nval a = 1\n' "$(gen_text "$unit" "$count")" > "$file"
    set_config none
    judge "$name" "$expect" "$(event_write "$PROJ/src/W.kt" "$file" | "$GATE")"
}

run_width_cases() {
    width_case "width allow: cyrillic 100 chars (bytes over 120)" allow 'слов ' 20
    width_case "width deny: cyrillic 130 chars" deny:width 'слов ' 26
    width_case "width allow: arabic 100 chars (bytes over 120)" allow 'كلمة ' 20
    width_case "width deny: arabic 130 chars" deny:width 'كلمة ' 26
    width_case "width allow: ascii comment of exactly 120" allow 'abcdefg ' 14
    width_case "width deny: ascii comment of 121" deny:width 'abcdefg ' 15
}

run_multiedit_case() {
    local ev out
    set_config none
    ev=$(jq -n --arg p "$PROJ/src/M.kt" '{
        tool_name: "MultiEdit",
        tool_input: {file_path: $p, edits: [
            {old_string: "val a = 1", new_string: "val a = 2"},
            {old_string: "val b = 1", new_string: "// Step 1: set b\nval b = 2"}
        ]}
    }')
    out=$(printf '%s' "$ev" | "$GATE")
    judge "multiedit deny: second edit carries narration" deny:step-narration "$out"
    ev=$(jq -n --arg p "$PROJ/src/M.kt" '{
        tool_name: "MultiEdit",
        tool_input: {file_path: $p, edits: [
            {old_string: "val a = 1", new_string: "val a = 2"},
            {old_string: "val b = 1", new_string: "val b = 2"}
        ]}
    }')
    out=$(printf '%s' "$ev" | "$GATE")
    judge "multiedit allow: clean edits" allow "$out"
}

run_other_tool_case() {
    local out
    out=$(jq -n '{tool_name: "Read", tool_input: {file_path: "/x/a.kt"}}' | "$GATE")
    judge "other tools pass through" allow "$out"
}

run_malicious_config_case() {
    local marker_dir="$WORK/pwn" out
    mkdir -p "$marker_dir" "$PROJ/.claude"
    printf '%s\n' \
        "ticket_regex=\$(touch $marker_dir/one)" \
        "exempt=\$(touch $marker_dir/two) \`touch $marker_dir/three\`" \
        "todo_anchor=\$(touch $marker_dir/four)" > "$PROJ/.claude/comment-rules"
    printf '// ==== banner\nval a = 1\n' > "$WORK/mal.kt"
    out=$(event_write "$PROJ/src/Mal.kt" "$WORK/mal.kt" | "$GATE" 2> /dev/null)
    judge "malicious config: gate still denies" deny:banner "$out"
    if [ -z "$(ls -A "$marker_dir")" ]; then ok "malicious config: nothing executed"; else bad "malicious config: nothing executed" "created $(ls "$marker_dir")"; fi
    (cd "$PROJ" && git add -A > /dev/null 2>&1 && "$GATE" --tree > /dev/null 2>&1)
    if [ -z "$(ls -A "$marker_dir")" ]; then ok "malicious config: tree mode executed nothing"; else bad "malicious config: tree mode executed nothing" "created $(ls "$marker_dir")"; fi
    rm -f "$PROJ/.claude/comment-rules"
}

run_claude_kit_self_case() {
    local self="$WORK/self" out
    new_repo "$self"
    mkdir -p "$self/plugin/scripts" "$self/.claude-plugin" "$self/test/fixtures"
    : > "$self/plugin/scripts/no-slop.sh"
    : > "$self/.claude-plugin/marketplace.json"
    printf '// Step 1: quoted on purpose\n' > "$WORK/self.kt"
    printf 'We removed the old flow.\n' > "$WORK/self.md"
    out=$(event_write "$self/test/fixtures/a.kt" "$WORK/self.kt" | "$GATE")
    judge "claude-kit repo: test fixtures are exempt" allow "$out"
    out=$(event_write "$self/plugin/false-positives.md" "$WORK/self.md" | "$GATE")
    judge "claude-kit repo: false-positives log is exempt" allow "$out"
    out=$(event_write "$self/README.md" "$WORK/self.md" | "$GATE")
    judge "claude-kit repo: README is checked" deny:changelog "$out"
    out=$(event_write "$self/src/a.kt" "$WORK/self.kt" | "$GATE")
    judge "claude-kit repo: other code is checked" deny:step-narration "$out"
}

cli() {
    local dir=$1
    shift
    CLI_OUT=$(cd "$dir" && "$GATE" "$@" 2>&1)
    CLI_STATUS=$?
}

expect_cli() {
    local name=$1 want_status=$2 want_text=$3
    if [ "$CLI_STATUS" -ne "$want_status" ]; then
        bad "$name" "exit $CLI_STATUS, wanted $want_status: $CLI_OUT"
        return
    fi
    case $CLI_OUT in
        *"$want_text"*) ok "$name" ;;
        *) bad "$name" "output lacks '$want_text': $CLI_OUT" ;;
    esac
}

expect_cli_absent() {
    local name=$1 text=$2
    case $CLI_OUT in
        *"$text"*) bad "$name" "output contains '$text': $CLI_OUT" ;;
        *) ok "$name" ;;
    esac
}

run_tree_cases() {
    local d="$WORK/tree"
    new_repo "$d"
    mkdir -p "$d/docs/specs" "$d/.claude"
    printf 'val a = 1\n' > "$d/ok1.kt"
    printf '// Step 1: x\nval a = 1\n' > "$d/bad1.kt"
    printf '# ==== x\nx = 1\n' > "$d/bad2.py"
    printf '# First we do\necho hi\n' > "$d/bad3.sh"
    printf '// Step 1: x\nval a = 1\n' > "$d/docs/specs/skip.kt"
    printf 'exempt=docs/specs/*\n' > "$d/.claude/comment-rules"
    git -C "$d" add -A > /dev/null

    cli "$d" --tree
    expect_cli "tree: reports path:line: rule: text" 1 "bad1.kt:1: step-narration: // Step 1: x"
    expect_cli "tree: counts files with violations" 1 "files with violations: 3 of 4 scanned"
    cli "$d" --tree --ceiling 3
    expect_cli "tree: ceiling met exactly" 0 "files with violations: 3 of 4 scanned"
    expect_cli_absent "tree: no lower-the-ceiling hint at the ceiling" "Lower the ceiling"
    cli "$d" --tree --ceiling 5
    expect_cli "tree: ceiling above count asks to lower it" 0 "Lower the ceiling to 3 in the same commit"
    cli "$d" --tree --ceiling 2
    expect_cli "tree: ceiling exceeded fails" 1 "ceiling is 2"

    printf 'val a = 1\n' > "$d/bad1.kt"
    printf 'x = 1\n' > "$d/bad2.py"
    printf 'echo hi\n' > "$d/bad3.sh"
    cli "$d" --tree
    expect_cli "tree: clean repo passes" 0 "files with violations: 0 of 4 scanned"

    printf 'ticket_regex=\\bBR-[0-9]+\\b\n' > "$d/.claude/comment-rules"
    printf '// see BR-7\nval a = 1\n' > "$d/bad1.kt"
    cli "$d" --tree
    expect_cli "tree: reads the repo config" 1 "bad1.kt:1: ticket-id"
    printf 'ticket_regex=\\bZZ-[0-9]+\\b\nexempt=docs/specs/*\n' > "$WORK/override-rules"
    cli "$d" --tree --config "$WORK/override-rules"
    expect_cli "tree: --config overrides the repo config" 0 "files with violations: 0 of 4 scanned"

    local w="$WORK/broken-walk" i=0
    new_repo "$w"
    while [ "$i" -lt 10 ]; do
        printf 'val a = %s\n' "$i" > "$w/f$i.kt"
        i=$((i + 1))
    done
    git -C "$w" add -A > /dev/null
    rm -f "$w"/f[0-5].kt
    cli "$w" --tree
    expect_cli "tree: a broken walk fails loudly" 1 "The walk is broken"
}

run_diff_cases() {
    local d="$WORK/diff"
    new_repo "$d"
    printf '%s\n' '// Step 1: old debt' 'val a = 1' '// r1' '// r2' '// r3' 'val b = 2' > "$d/Debt.kt"
    printf '%s\n' '// Step 1: other debt' 'val o = 1' > "$d/Other.kt"
    git -C "$d" add -A > /dev/null
    git -C "$d" commit -q -m base

    git -C "$d" checkout -q -b change
    printf '%s\n' '// Step 1: old debt' 'val a = 1' '// r1' '// r2' '// r3' '// r4' 'val b = 2' 'val c = 3' > "$d/Debt.kt"
    printf '%s\n' '// Step 1: other debt' 'val o = 1' 'val p = 2' > "$d/Other.kt"
    printf '%s\n' '// ==== banner' 'class AManager' > "$d/New.kt"
    printf '%s\n' 'export const a = 1' > "$d/utils.ts"
    git -C "$d" add -A > /dev/null
    git -C "$d" commit -q -m change

    cli "$d" --diff main
    expect_cli "diff: run that gains a line is reported" 1 "Debt.kt:3: run-cap"
    expect_cli "diff: new file banner is reported" 1 "New.kt:1: banner"
    expect_cli "diff: new file banned name is reported" 1 "New.kt:2: banned-name"
    expect_cli "diff: new utils file is reported" 1 "utils.ts:1: banned-name"
    expect_cli_absent "diff: inherited narration is not reported" "Debt.kt:1:"
    expect_cli_absent "diff: file with only clean additions is not reported" "Other.kt"

    git -C "$d" checkout -q main
    git -C "$d" checkout -q -b clean
    printf '%s\n' '// Step 1: old debt' 'val a = 1' '// r1' '// r2' '// r3' 'val b = 2' 'val c = 3' > "$d/Debt.kt"
    git -C "$d" add -A > /dev/null
    git -C "$d" commit -q -m clean
    cli "$d" --diff main
    expect_cli "diff: clean additions to debt files pass" 0 ""

    cli "$d" --diff no-such-ref
    expect_cli "diff: unknown base fails with a hint" 2 "fetch-depth: 0"

    printf '%s\n' '// Step 1: old debt' 'val a = 1' '// r1' '// r2' '// r3' 'val b = 2' 'val c = 3' '// Then we save' > "$d/Debt.kt"
    git -C "$d" add -A > /dev/null
    printf '%s\n' '// Step 1: old debt' 'val a = 1' '// r1' '// r2' '// r3' 'val b = 2' 'val c = 3' '// Then we save' '// ==== unstaged' > "$d/Debt.kt"
    cli "$d" --staged
    expect_cli "staged: added line in the index is reported" 1 "Debt.kt:8: step-narration"
    expect_cli_absent "staged: unstaged line is not reported" "unstaged"
}

inplace_case() {
    local want=$1 cmd=$2 cwd=$3 out got
    out=$(jq -n --arg c "$cmd" --arg d "$cwd" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
        "$ROOT/plugin/scripts/block-inplace-edits.sh")
    got=allow
    [ -n "$out" ] && got=deny
    if [ "$got" = "$want" ]; then ok "inplace $want: $cmd (cwd $cwd)"; else bad "inplace: $cmd (cwd $cwd)" "want $want, got $got"; fi
}

run_inplace_cases() {
    mkdir -p "$PROJ/sub"
    : > "$PROJ/existing.txt"
    : > "$PROJ/sub/inner.txt"
    inplace_case allow "cd /nonexistent/repo && printf x > existing.txt" "$PROJ"
    inplace_case deny "printf x > existing.txt" "$PROJ"
    inplace_case deny "cd $PROJ && printf x > existing.txt" "/"
    inplace_case deny "cd sub && echo x > inner.txt" "$PROJ"
    inplace_case allow "cd sub && echo x > new.txt" "$PROJ"
    inplace_case allow "printf x > existing.txt" "/"
    inplace_case deny "echo x > $PROJ/existing.txt" "/"
    inplace_case deny "sed -i 's/a/b/' existing.txt" "$PROJ"
    inplace_case deny "bulk-edit 30" "$PROJ"
    inplace_case deny "cd x && bulk-edit 30" "$PROJ"
    inplace_case deny "zsh -ic 'bulk-edit 30'" "$PROJ"
    inplace_case deny "touch ~/.claude/bulk-edit.allow" "$PROJ"
    inplace_case allow "git commit -m 'feat: the bulk-edit gate'" "$PROJ"
    inplace_case allow "grep -n bulk-edit README.md" "$PROJ"
}

# shellcheck source=test/sync-kit.sh
. "$ROOT/test/sync-kit.sh"
# shellcheck source=test/commit-msg.sh
. "$ROOT/test/commit-msg.sh"
# shellcheck source=test/kit-init.sh
. "$ROOT/test/kit-init.sh"
# shellcheck source=test/check-publishable.sh
. "$ROOT/test/check-publishable.sh"
# shellcheck source=test/install.sh
. "$ROOT/test/install.sh"

main() {
    mkdir -p "$WORK/cases" "$PROJ"
    new_repo "$PROJ"
    split_cases
    local count i
    count=$(cat "$WORK/cases/count")
    i=1
    while [ "$i" -le "$count" ]; do
        run_case_file "$i"
        i=$((i + 1))
    done
    run_width_cases
    run_multiedit_case
    run_other_tool_case
    run_malicious_config_case
    run_claude_kit_self_case
    run_tree_cases
    run_diff_cases
    run_inplace_cases
    run_sync_kit_cases
    run_sync_kit_timeout_case
    run_commit_msg_cases
    run_kit_init_cases
    run_check_publishable_cases
    run_install_cases
    printf '%s passed, %s failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ]
}

main
