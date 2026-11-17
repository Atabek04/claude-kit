#!/bin/bash
# PreToolUse(Bash): denies scripted file edits unless every write lands in a clean git work tree.
# Why a hook and not prose: docs/gates.md, "Why hooks instead of prose". Scratch paths stay writable.

EVENT=$(cat)
COMMAND=$(printf '%s' "$EVENT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0
SESSION_CWD=$(printf '%s' "$EVENT" | jq -r '.cwd // empty')

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

# A relative path resolves against the command's own leading `cd`, else the session cwd, never the hook's cwd.
CD_DIR=$(printf '%s' "$COMMAND" | sed -nE 's/^[[:space:]]*cd[[:space:]]+"?([^"[:space:];&|]+)"?[[:space:]]*&&.*/\1/p')
case "$CD_DIR" in
    "~"*) CD_DIR="$HOME${CD_DIR#\~}" ;;
    /* | "") ;;
    *) CD_DIR="${SESSION_CWD:-.}/$CD_DIR" ;;
esac
WORK_DIR="${CD_DIR:-${SESSION_CWD:-.}}"

USE_EDIT="Use the Read/Edit/Write tools, or commit first and rerun the script in the clean tree; then print the \
changed-file count and grep that the old string is gone."

# A clean tree makes a scripted edit reviewable (`git diff`) and reversible (`git checkout .`); a dirty one can lose
# uncommitted work. Every absolute or home path the command names must sit inside that tree.
deny_unless_clean_tree() {
    local top candidate first
    top=$(git -C "$WORK_DIR" rev-parse --show-toplevel 2> /dev/null)
    [ -z "$top" ] && deny "$1 Scripted edits run only inside a git work tree. $USE_EDIT"
    [ -n "$(git -C "$top" status --porcelain 2> /dev/null)" ] &&
        deny "$1 The work tree $top has uncommitted changes. $USE_EDIT"
    # A sed or regex literal such as /^B16 x/ is not a path: only a token whose first directory exists counts.
    while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        first=${candidate#/}
        first=/${first%%/*}
        [ "$first" != "/" ] && [ -e "$first" ] || continue
        printf '%s' "$candidate" | grep -qE '^/dev/' && continue
        # Resolved like git's toplevel: a symlinked checkout path stays inside, a link out of the tree does not.
        realpath -m -- "$candidate" | grep -qE "^$top(/|$)" && continue
        deny "$1 It names '$candidate', outside the work tree $top. $USE_EDIT"
    done < <(printf '%s' "$COMMAND" | grep -oE "(^|[[:space:]\"'=])(/|~|\\\$HOME)[^[:space:]\"';|&)]*" |
        sed -E "s/^[[:space:]\"'=]//; s|^~|$HOME|; s|^\\\$HOME|$HOME|")
    exit 0
}

# sed -i / perl -i, in every flag spelling: -i, -i.bak, -ni, -i -e
if printf '%s' "$COMMAND" | grep -qE '(^|[|;&[:space:]])(sed|perl)([[:space:]]+-[A-Za-z]*)*[[:space:]]+-[A-Za-z]*i'; then
    deny_unless_clean_tree "In-place sed/perl edit: it reports success after changing nothing."
fi

# Any interpreter that writes a file back, asserted or not.
if printf '%s' "$COMMAND" | grep -qE '(^|[|;&[:space:]])(python3?|ruby|node|deno|php)([[:space:]]|$)' \
    && printf '%s' "$COMMAND" | grep -qE '(\.write\(|\.write_text\(|writeFileSync|File\.write|\.writelines\(|open\([^)]*["'"'"']w)'; then
    deny_unless_clean_tree "Script writing a project file."
fi

# Redirecting over a file that already exists is a blind overwrite; creating a new one is fine.
TARGET=$(printf '%s' "$COMMAND" | sed -nE 's/.*[^>]>[[:space:]]*"?([^"[:space:]|;&]+).*/\1/p' | head -1)
case "$TARGET" in
    /* | "") ;;
    "~"*) TARGET="$HOME${TARGET#\~}" ;;
    *) TARGET="$WORK_DIR/$TARGET" ;;
esac
if [ -n "$TARGET" ] && [ -f "$TARGET" ] \
    && ! printf '%s' "$TARGET" | grep -qE '^(/tmp/|/var/folders/)' \
    && printf '%s' "$COMMAND" | grep -qE '(^|[|;&[:space:]])(cat|tee|printf|echo)([[:space:]]|$)'; then
    deny_unless_clean_tree "Redirect overwrites the existing file '$TARGET' with no read first."
fi

exit 0
