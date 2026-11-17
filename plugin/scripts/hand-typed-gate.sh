#!/bin/bash
# PreToolUse(Write|Edit|MultiEdit): denies writing code under a directory holding a `.hand-typed` file.
# A learning sandbox: the owner types every line, Claude answers questions. Rule: rules/hand-typed.md.

EVENT=$(cat)
FILE=$(printf '%s' "$EVENT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

case "$FILE" in
    *.java | *.kt | *.kts | *.py | *.go | *.ts | *.tsx | *.js | *.sql) ;;
    *) exit 0 ;;
esac

DIR=$(dirname "$FILE")
while :; do
    if [ -f "$DIR/.hand-typed" ]; then
        jq -n --arg reason "$DIR is a hand-typed learning sandbox (.hand-typed): the owner types every line here. \
Answer the question, point to the file and line, explain a compiler error by its cause; never write the code, \
not even the fixed line. To lift it, the owner deletes .hand-typed." '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason
            }
        }'
        exit 2
    fi
    [ "$DIR" = / ] || [ "$DIR" = . ] && break
    DIR=$(dirname "$DIR")
done
exit 0
