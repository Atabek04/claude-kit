#!/bin/bash
# SessionStart(startup): fast-forwards the kit clone, then reports only what needs attention as one context line.
# Always exits 0. The network step is bounded by KIT_SYNC_TIMEOUT seconds (default 10).

KIT="${CLAUDE_KIT:-$HOME/claude-kit}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LIMIT_SECONDS="${KIT_SYNC_TIMEOUT:-10}"

NOTES=""
note() {
    NOTES="${NOTES:+$NOTES; }$1"
}

# macOS has no timeout(1), so the child is polled and killed with its own children (ssh) at the limit.
run_bounded() {
    local limit_ticks=$(($1 * 5)) ticks=0 pid
    shift
    "$@" > /dev/null 2>&1 &
    pid=$!
    while kill -0 "$pid" 2> /dev/null; do
        if [ "$ticks" -ge "$limit_ticks" ]; then
            pkill -P "$pid" 2> /dev/null
            kill "$pid" 2> /dev/null
            break
        fi
        sleep 0.2
        ticks=$((ticks + 1))
    done
    wait "$pid" 2> /dev/null
}

check_clone() {
    local before after behind ahead dirty
    if ! git -C "$KIT" rev-parse --git-dir > /dev/null 2>&1; then
        note "the kit clone is missing at $KIT; clone Atabek04/claude-kit there and run its install.sh"
        return
    fi

    before=$(git -C "$KIT" rev-parse --short HEAD 2> /dev/null)
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes -o ConnectTimeout=8" \
        run_bounded "$LIMIT_SECONDS" git -C "$KIT" pull --ff-only --quiet
    after=$(git -C "$KIT" rev-parse --short HEAD 2> /dev/null)

    read -r ahead behind < <(git -C "$KIT" rev-list --left-right --count 'HEAD...@{u}' 2> /dev/null || echo "0 0")
    dirty=$(git -C "$KIT" status --porcelain 2> /dev/null | wc -l | tr -d ' ')

    if [ "${ahead:-0}" -gt 0 ] && [ "${behind:-0}" -gt 0 ]; then
        note "$KIT has diverged from origin ($ahead local, $behind remote commits); it needs a rebase before it can sync"
    elif [ "${behind:-0}" -gt 0 ]; then
        note "$KIT is $behind commits behind origin and could not fast-forward (local changes in the way?)"
    elif [ "${ahead:-0}" -gt 0 ]; then
        note "$KIT has $ahead unpushed commits; offer to push them"
    fi
    if [ "$dirty" -gt 0 ]; then
        note "$KIT has $dirty files with uncommitted changes; offer to commit and push them"
    fi
    if [ -n "$before" ] && [ "$before" != "$after" ]; then
        note "$KIT pulled to $after; rule changes take effect next session"
    fi
}

check_wiring() {
    local import_line="@$KIT/CLAUDE.md" tilde_line="@~/claude-kit/CLAUDE.md"
    if ! grep -qxF -e "$tilde_line" -e "$import_line" "$CLAUDE_DIR/CLAUDE.md" 2> /dev/null; then
        note "$CLAUDE_DIR/CLAUDE.md lacks the $tilde_line import; run $KIT/install.sh"
    fi
    if [ ! -L "$CLAUDE_DIR/rules/kit" ] || [ ! -d "$CLAUDE_DIR/rules/kit" ]; then
        note "the $CLAUDE_DIR/rules/kit symlink to $KIT/rules is missing; run $KIT/install.sh"
    fi
}

emit() {
    [ -z "$NOTES" ] && return
    if command -v jq > /dev/null 2>&1; then
        jq -nc --arg context "claude-kit: $NOTES" \
            '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}}'
    else
        printf 'claude-kit: %s\n' "$NOTES"
    fi
}

check_clone
check_wiring
emit
exit 0
