#!/bin/bash
# shellcheck disable=SC2154
# Cases for plugin/scripts/commit-msg.sh. Sourced by run.sh, which provides ROOT, WORK and the assert helpers.

COMMIT_MSG_SCRIPT="$ROOT/plugin/scripts/commit-msg.sh"

commit_msg_case() {
    local name=$1 want=$2 text=$3 file="$WORK/commit-msg.txt" got
    printf '%s\n' "$text" > "$file"
    "$COMMIT_MSG_SCRIPT" "$file" > /dev/null 2>&1
    got=$?
    if [ "$got" -eq "$want" ]; then ok "commit-msg: $name"; else bad "commit-msg: $name" "exit $got, wanted $want"; fi
}

run_commit_msg_cases() {
    local robot trailer_name
    robot=$(printf '\360\237\244\226')
    trailer_name="Co-Authored-By"

    commit_msg_case "allow plain type" 0 "feat: add the sync hook"
    commit_msg_case "allow scope" 0 "fix(api): reject empty bodies"
    commit_msg_case "allow breaking marker" 0 "feat(api)!: drop the v1 routes"
    commit_msg_case "allow breaking marker without scope" 0 "refactor!: rename the entry point"
    commit_msg_case "allow scope with dash and slash" 0 "chore(deps-dev/npm): bump the lockfile"
    commit_msg_case "allow every listed type: test" 0 "test: cover the diff mode"
    commit_msg_case "allow every listed type: docs" 0 "docs: explain the gate"
    commit_msg_case "allow every listed type: perf" 0 "perf: skip unchanged files"
    commit_msg_case "allow every listed type: build" 0 "build: pin the toolchain"
    commit_msg_case "allow every listed type: ci" 0 "ci: add the secret scan"
    commit_msg_case "allow every listed type: style" 0 "style: wrap long lines"
    commit_msg_case "allow every listed type: revert" 0 "revert: feat: add the sync hook"
    commit_msg_case "allow body and trailers" 0 "feat: add x

Why this matters.

$trailer_name: Jane Doe <jane@example.com>"
    commit_msg_case "allow a subject that merely mentions the kit" 0 "feat: add the claude-kit hooks"
    commit_msg_case "allow subject after git comment lines" 0 "# Please enter the commit message
feat: add x"
    commit_msg_case "allow merge commit" 0 "Merge branch 'main' into feature"
    commit_msg_case "allow fixup" 0 "fixup! feat: add x"
    commit_msg_case "allow squash" 0 "squash! fix: y"
    commit_msg_case "allow git revert message" 0 "Revert \"feat: add x\"

This reverts commit abc123."
    commit_msg_case "allow empty message (git aborts it)" 0 "# only comments"

    commit_msg_case "deny sentence subject" 1 "Add the sync hook"
    commit_msg_case "deny capitalised type" 1 "Feat: add x"
    commit_msg_case "deny missing space after colon" 1 "feat:add x"
    commit_msg_case "deny empty scope" 1 "feat(): add x"
    commit_msg_case "deny unknown type" 1 "feature: add x"
    commit_msg_case "deny missing colon" 1 "feat add x"
    commit_msg_case "deny empty description" 1 "feat: "
    commit_msg_case "deny Claude co-author trailer" 1 "feat: add x

$trailer_name: Claude <noreply@anthropic.com>"
    commit_msg_case "deny lowercase Anthropic co-author trailer" 1 "feat: add x

co-authored-by: Some Bot <noreply@anthropic.com>"
    commit_msg_case "deny generated-with line" 1 "feat: add x

Generated with [Claude Code](https://claude.com/claude-code)"
    commit_msg_case "deny robot emoji line" 1 "feat: add x

$robot made by a tool"
    commit_msg_case "deny attribution in a merge message" 1 "Merge branch 'x'

$trailer_name: Claude <noreply@anthropic.com>"
    commit_msg_case "deny attribution in a fixup" 1 "fixup! feat: add x

$robot Generated with Claude Code"
}
