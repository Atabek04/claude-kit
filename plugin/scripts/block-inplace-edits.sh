#!/bin/bash
# PreToolUse(Bash): denies scripted file edits unless the user opened a window with `bulk-edit N`.
# Why a hook and not prose: docs/gates.md, "Why hooks instead of prose". Scratch paths stay writable.

EVENT=$(cat)
COMMAND=$(printf '%s' "$EVENT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0
SESSION_CWD=$(printf '%s' "$EVENT" | jq -r '.cwd // empty')

GATE="$HOME/.claude/bulk-edit.allow"

deny() {
    jq -n --arg reason "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 2
}

# Only `bulk-edit` in command position opens the gate; the word inside a message or a path is prose.
if printf '%s' "$COMMAND" | grep -qE 'bulk-edit\.allow|(^|[|;&(]|-[a-z]*c)[[:space:]]*["'"'"']?bulk-edit([[:space:]]|["'"'"']|$)'; then
    deny "The bulk-edit gate is opened by the user in their own terminal (\`bulk-edit N\`), never by the agent. Ask them."
fi

if [ -f "$GATE" ]; then
    EXPIRY=$(tr -dc '0-9' < "$GATE")
    if [ -n "$EXPIRY" ] && [ "$(date +%s)" -lt "$EXPIRY" ]; then
        exit 0
    fi
    rm -f "$GATE"
fi

# Anything whose WRITE targets are all scratch is not a project edit, even when it reads project
# files to get there. Reading a path is not writing it, so a mentioned project path cannot by
# itself disqualify the exemption.
SCRATCH_RE='(/tmp/|/scratchpad/|\$SCRATCH|/var/folders/)'
# Only paths actually being WRITTEN. `open(p)` and `open(p,'r')` are reads and must not count,
# or a command that reads a project file to build a scratch file looks like a project edit.
WRITE_TARGETS=$(
    printf '%s' "$COMMAND" | grep -oE "open\([\"'][^\"']+[\"'][[:space:]]*,[[:space:]]*[\"'][wa]" |
        sed -E "s/^open\([\"']//; s/[\"'].*$//"
    printf '%s' "$COMMAND" | grep -oE "(>>?|--output[= ]|-o )[[:space:]]*[\"']?[^\"'[:space:]),|]+" |
        sed -E "s/^(>>?|--output[= ]|-o )[[:space:]]*[\"']?//"
)

if [ -n "$WRITE_TARGETS" ] && printf '%s' "$COMMAND" | grep -qE "$SCRATCH_RE"; then
    all_scratch=1
    while IFS= read -r target; do
        [ -z "$target" ] && continue
        printf '%s' "$target" | grep -qE "$SCRATCH_RE" || all_scratch=0
    done <<< "$WRITE_TARGETS"
    [ "$all_scratch" -eq 1 ] && exit 0
fi

# No write target at all, and scratch mentioned: a read-only command.
if ! printf '%s' "$COMMAND" | grep -qE '(open\([^)]*["'"'"']w|>|>>)' \
    && printf '%s' "$COMMAND" | grep -qE "$SCRATCH_RE"; then
    exit 0
fi

USE_EDIT="Use the Read/Edit/Write tools instead. This is ~/.claude/CLAUDE.md, 'File editing', enforced by a hook because the auto-mode system-reminder keeps overriding it in prose. For a deliberate bulk refactor, show the user the change map and ask them to run \`bulk-edit N\` (minutes) in their terminal; do not retry until they confirm."

# sed -i / perl -i, in every flag spelling: -i, -i.bak, -ni, -i -e
if printf '%s' "$COMMAND" | grep -qE '(^|[|;&[:space:]])(sed|perl)([[:space:]]+-[A-Za-z]*)*[[:space:]]+-[A-Za-z]*i'; then
    deny "In-place sed/perl edit blocked: it reports success after changing nothing. $USE_EDIT"
fi

# Any interpreter that writes a file back, asserted or not.
if printf '%s' "$COMMAND" | grep -qE '(^|[|;&[:space:]])(python3?|ruby|node|deno|php)([[:space:]]|$)' \
    && printf '%s' "$COMMAND" | grep -qE '(\.write\(|\.write_text\(|writeFileSync|File\.write|\.writelines\(|open\([^)]*["'"'"']w)'; then
    deny "Script writing a project file blocked. $USE_EDIT"
fi

# Redirecting over a file that already exists is a blind overwrite; creating a new one is fine.
TARGET=$(printf '%s' "$COMMAND" | sed -nE 's/.*[^>]>[[:space:]]*"?([^"[:space:]|;&]+).*/\1/p' | head -1)
# A relative target resolves against the command's own leading `cd`, else the session cwd, never the hook's cwd.
CD_DIR=$(printf '%s' "$COMMAND" | sed -nE 's/^[[:space:]]*cd[[:space:]]+"?([^"[:space:];&|]+)"?[[:space:]]*&&.*/\1/p')
case "$CD_DIR" in
    "~"*) CD_DIR="$HOME${CD_DIR#\~}" ;;
    /* | "") ;;
    *) CD_DIR="${SESSION_CWD:-.}/$CD_DIR" ;;
esac
case "$TARGET" in
    /* | "") ;;
    "~"*) TARGET="$HOME${TARGET#\~}" ;;
    *) TARGET="${CD_DIR:-${SESSION_CWD:-.}}/$TARGET" ;;
esac
if [ -n "$TARGET" ] && [ -f "$TARGET" ] \
    && ! printf '%s' "$TARGET" | grep -qE '^(/tmp/|/var/folders/)' \
    && printf '%s' "$COMMAND" | grep -qE '(^|[|;&[:space:]])(cat|tee|printf|echo)([[:space:]]|$)'; then
    deny "Redirect would overwrite the existing file '$TARGET' with no read first. $USE_EDIT"
fi

exit 0
