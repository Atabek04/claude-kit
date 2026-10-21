#!/bin/bash
# shellcheck disable=SC2154
# Cases for plugin/scripts/sync-kit.sh. Sourced by run.sh, which provides ROOT, WORK, new_repo and the assert helpers.

SYNC_SCRIPT="$ROOT/plugin/scripts/sync-kit.sh"
SYNC_IMPORT='@~/claude-kit/CLAUDE.md'

sync_fixture() {
    local s="$WORK/sync"
    rm -rf "$s"
    mkdir -p "$s/home/.claude/rules"
    git init -q --bare "$s/remote.git"
    git -C "$s/remote.git" symbolic-ref HEAD refs/heads/main
    new_repo "$s/pusher"
    mkdir -p "$s/pusher/rules"
    : > "$s/pusher/rules/.gitkeep"
    printf '# rules\n' > "$s/pusher/CLAUDE.md"
    git -C "$s/pusher" add -A
    git -C "$s/pusher" commit -q -m "feat: seed"
    git -C "$s/pusher" remote add origin "$s/remote.git"
    git -C "$s/pusher" push -q origin main
    git clone -q "$s/remote.git" "$s/kit"
    git -C "$s/kit" config user.email test@example.com
    git -C "$s/kit" config user.name test
    git -C "$s/kit" config commit.gpgsign false
    printf '%s\n' "$SYNC_IMPORT" > "$s/home/.claude/CLAUDE.md"
    ln -s "$s/kit/rules" "$s/home/.claude/rules/kit"
}

run_sync() {
    local s="$WORK/sync"
    SYNC_OUT=$(env -u CLAUDE_CONFIG_DIR HOME="$s/home" CLAUDE_KIT="${1:-$s/kit}" KIT_SYNC_TIMEOUT="${2:-10}" "$SYNC_SCRIPT" 2> /dev/null)
    SYNC_STATUS=$?
}

run_kit_ack() {
    local s="$WORK/sync"
    env -u CLAUDE_CONFIG_DIR HOME="$s/home" CLAUDE_KIT="$s/kit" "$ROOT/plugin/scripts/kit-ack.sh" > /dev/null 2>&1
}

push_from_pusher() {
    local s="$WORK/sync"
    printf '%s\n' "$1" >> "$s/pusher/CLAUDE.md"
    git -C "$s/pusher" commit -q -am "feat: $1"
    git -C "$s/pusher" push -q origin main
}

run_sync_kit_cases() {
    local s="$WORK/sync" context

    sync_fixture
    run_sync
    assert_eq "sync-kit: up to date is silent" "0:" "$SYNC_STATUS:$SYNC_OUT"

    push_from_pusher "rule one"
    run_sync
    assert_eq "sync-kit: behind clone is fast-forwarded" "$(git -C "$s/pusher" rev-parse HEAD)" "$(git -C "$s/kit" rev-parse HEAD)"
    assert_has "sync-kit: pull is reported with the next-session note" "$SYNC_OUT" "rule changes take effect next session"
    context=$(printf '%s' "$SYNC_OUT" | jq -r '.hookSpecificOutput | .hookEventName + "|" + .additionalContext' 2> /dev/null)
    assert_has "sync-kit: output is SessionStart additionalContext JSON" "$context" "SessionStart|claude-kit: "
    assert_eq "sync-kit: report is one line" "1" "$(printf '%s\n' "$SYNC_OUT" | wc -l | tr -d ' ')"
    assert_has "sync-kit: moved range is reported against the checkpoint" "$SYNC_OUT" "kit moved "
    assert_has "sync-kit: a range without Action lines says 0 Action" "$SYNC_OUT" "1 commits, 0 Action"
    run_sync
    assert_has "sync-kit: the checkpoint keeps reporting until acknowledged" "$SYNC_OUT" "kit moved "
    run_kit_ack
    run_sync
    assert_eq "sync-kit: second run is silent after the acknowledgement" "0:" "$SYNC_STATUS:$SYNC_OUT"

    sync_fixture
    run_sync
    push_from_pusher "rule two"
    printf 'x\n' >> "$s/pusher/CLAUDE.md"
    git -C "$s/pusher" commit -q -am "feat: hook change" -m "Action: re-run install.sh on each device"
    git -C "$s/pusher" push -q origin main
    run_sync
    assert_has "sync-kit: Action lines are counted" "$SYNC_OUT" "2 commits, 1 Action"
    assert_has "sync-kit: Action text is carried into the context" "$SYNC_OUT" "Action: re-run install.sh on each device"

    sync_fixture
    run_sync
    printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' > "$s/home/.claude/kit-seen"
    run_sync
    assert_has "sync-kit: a checkpoint outside the history is reported" "$SYNC_OUT" "not an ancestor"
    run_kit_ack
    run_sync
    assert_eq "sync-kit: acknowledging repairs a foreign checkpoint" "0:" "$SYNC_STATUS:$SYNC_OUT"

    sync_fixture
    printf 'local edit\n' >> "$s/kit/CLAUDE.md"
    run_sync
    assert_has "sync-kit: uncommitted changes are named" "$SYNC_OUT" "uncommitted changes"
    assert_has "sync-kit: uncommitted changes offer a push" "$SYNC_OUT" "offer to commit and push"

    sync_fixture
    printf 'local commit\n' >> "$s/kit/CLAUDE.md"
    git -C "$s/kit" commit -q -am "feat: local"
    run_sync
    assert_has "sync-kit: unpushed commits are named" "$SYNC_OUT" "1 unpushed commits"

    sync_fixture
    push_from_pusher "remote side"
    printf 'local side\n' >> "$s/kit/rules/local.md"
    git -C "$s/kit" add -A
    git -C "$s/kit" commit -q -m "feat: local side"
    run_sync
    assert_has "sync-kit: divergence is reported" "$SYNC_OUT" "diverged"

    sync_fixture
    printf 'only my notes\n' > "$s/home/.claude/CLAUDE.md"
    run_sync
    assert_has "sync-kit: missing import is reported" "$SYNC_OUT" "lacks the $SYNC_IMPORT import"

    sync_fixture
    rm "$s/home/.claude/rules/kit"
    run_sync
    assert_has "sync-kit: missing rules symlink is reported" "$SYNC_OUT" "rules/kit symlink"

    sync_fixture
    run_sync "$s/absent"
    assert_has "sync-kit: missing clone is reported" "$SYNC_OUT" "clone is missing"
    assert_eq "sync-kit: missing clone still exits 0" "0" "$SYNC_STATUS"
}

run_sync_kit_timeout_case() {
    local s="$WORK/sync" real_git started elapsed
    sync_fixture
    real_git=$(command -v git)
    mkdir -p "$s/fakebin"
    printf '#!/bin/bash\nfor arg in "$@"; do [ "$arg" = pull ] && exec sleep 30; done\nexec "%s" "$@"\n' "$real_git" > "$s/fakebin/git"
    chmod +x "$s/fakebin/git"
    started=$SECONDS
    SYNC_OUT=$(PATH="$s/fakebin:$PATH" env -u CLAUDE_CONFIG_DIR HOME="$s/home" CLAUDE_KIT="$s/kit" KIT_SYNC_TIMEOUT=1 "$SYNC_SCRIPT" 2> /dev/null)
    SYNC_STATUS=$?
    elapsed=$((SECONDS - started))
    assert_eq "sync-kit: a hanging pull is cut off and exits 0" "0" "$SYNC_STATUS"
    if [ "$elapsed" -le 6 ]; then ok "sync-kit: a hanging pull returns within the bound (${elapsed}s)"; else bad "sync-kit: a hanging pull returns within the bound" "took ${elapsed}s"; fi
}
