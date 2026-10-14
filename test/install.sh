#!/bin/bash
# shellcheck disable=SC2154
# Cases for install.sh against a throwaway HOME with shimmed claude and gh. Sourced by run.sh, which provides ROOT,
# WORK, new_repo and the assert helpers.

INSTALL_SCRIPT="$ROOT/install.sh"

install_fixture() {
    local t="$WORK/install"
    rm -rf "$t"
    mkdir -p "$t/home" "$t/shims" "$t/state"
    git init -q --bare "$t/remote.git"
    git -C "$t/remote.git" symbolic-ref HEAD refs/heads/main
    new_repo "$t/pusher"
    printf '# rules\n' > "$t/pusher/CLAUDE.md"
    git -C "$t/pusher" add -A
    git -C "$t/pusher" commit -q -m "feat: seed"
    git -C "$t/pusher" remote add origin "$t/remote.git"
    git -C "$t/pusher" push -q origin main

    cat > "$t/shims/claude" << 'SHIM'
#!/bin/bash
state="$SHIM_STATE"
echo "$*" >> "$state/calls"
case "$*" in
    "plugin marketplace list --json") cat "$state/marketplaces.json" 2> /dev/null || echo '[]' ;;
    "plugin list --json") cat "$state/plugins.json" 2> /dev/null || echo '[]' ;;
    "plugin marketplace add "*) echo '[{"name":"claude-kit"}]' > "$state/marketplaces.json" ;;
    "plugin install "*) echo '[{"id":"kit@claude-kit"}]' > "$state/plugins.json" ;;
    *) exit 1 ;;
esac
SHIM
    printf '#!/bin/bash\n[ "$1 $2" = "auth token" ] && exit 0\nexit 1\n' > "$t/shims/gh"
    chmod +x "$t/shims/claude" "$t/shims/gh"
}

run_install() {
    local t="$WORK/install"
    INSTALL_OUT=$(env -u CLAUDE_CONFIG_DIR -u ZDOTDIR -u CLAUDE_KIT \
        HOME="$t/home" PATH="$t/shims:$PATH" SHIM_STATE="$t/state" CLAUDE_KIT_REMOTE="$t/remote.git" \
        "$INSTALL_SCRIPT" "$@" 2>&1)
    INSTALL_STATUS=$?
}

run_install_cases() {
    local t="$WORK/install" h="$WORK/install/home" before after

    install_fixture
    run_install --check
    assert_eq "install --check: reports work to do with exit 1" "1" "$INSTALL_STATUS"
    assert_has "install --check: names the clone as todo" "$INSTALL_OUT" "todo  clone Atabek04/claude-kit"
    assert_has "install --check: names the plugin as todo" "$INSTALL_OUT" "todo  claude plugin marketplace add"
    local touched=0
    [ -e "$h/claude-kit" ] && touched=1
    [ -e "$h/.claude" ] && touched=1
    [ -e "$h/.zshrc" ] && touched=1
    grep -qE 'add|install' "$t/state/calls" 2> /dev/null && touched=1
    assert_eq "install --check: creates and runs nothing" "0" "$touched"

    run_install
    assert_eq "install: first run succeeds" "0" "$INSTALL_STATUS"
    if [ -d "$h/claude-kit/.git" ]; then ok "install: clones the kit"; else bad "install: clones the kit" "no clone at $h/claude-kit"; fi
    assert_eq "install: CLAUDE.md starts with the import" "@~/claude-kit/CLAUDE.md" "$(head -n 1 "$h/.claude/CLAUDE.md")"
    assert_eq "install: rules link points at the clone" "$h/claude-kit/rules" "$(readlink "$h/.claude/rules/kit")"
    if [ -f "$h/claude-kit/rules/.gitkeep" ]; then ok "install: creates rules/.gitkeep"; else bad "install: creates rules/.gitkeep" "missing"; fi
    assert_has "install: adds the marketplace" "$(cat "$t/state/calls")" "plugin marketplace add Atabek04/claude-kit"
    assert_has "install: installs the plugin" "$(cat "$t/state/calls")" "plugin install kit@claude-kit"
    assert_eq "install: enables marketplace auto-update" "true" "$(jq -r '.extraKnownMarketplaces["claude-kit"].autoUpdate' "$h/.claude/settings.json")"
    assert_has "install: sources bulk-edit in .zshrc" "$(cat "$h/.zshrc")" "source ~/claude-kit/shell/bulk-edit.zsh"

    before=$(cat "$h/.claude/CLAUDE.md" "$h/.claude/settings.json" "$h/.zshrc" | cksum)
    run_install
    after=$(cat "$h/.claude/CLAUDE.md" "$h/.claude/settings.json" "$h/.zshrc" | cksum)
    assert_eq "install: second run changes no file" "$before" "$after"
    assert_lacks "install: second run does nothing" "$INSTALL_OUT" "  done"
    assert_eq "install: second run adds no plugin calls" "2" "$(grep -cE 'add|install' "$t/state/calls")"

    run_install --check
    assert_eq "install --check: clean machine exits 0" "0" "$INSTALL_STATUS"
    assert_has "install --check: clean machine says nothing to do" "$INSTALL_OUT" "Nothing to do."

    install_fixture
    mkdir -p "$h/.claude"
    printf 'my own notes\n' > "$h/.claude/CLAUDE.md"
    printf '{"env":{"TOKEN":"sentinel-value-1234"},"theme":"dark"}\n' > "$h/.claude/settings.json"
    chmod 600 "$h/.claude/settings.json"
    run_install
    assert_eq "install: keeps existing CLAUDE.md content" "my own notes" "$(tail -n 1 "$h/.claude/CLAUDE.md")"
    assert_eq "install: existing CLAUDE.md gains the import first" "@~/claude-kit/CLAUDE.md" "$(head -n 1 "$h/.claude/CLAUDE.md")"
    assert_eq "install: settings keep unrelated keys" "sentinel-value-1234|dark" "$(jq -r '.env.TOKEN + "|" + .theme' "$h/.claude/settings.json")"
    assert_eq "install: settings keep mode 600" "600" "$(stat -c %a "$h/.claude/settings.json" 2> /dev/null || stat -f %Lp "$h/.claude/settings.json")"
    assert_lacks "install: output never echoes settings values" "$INSTALL_OUT" "sentinel-value"
    run_install --check
    assert_lacks "install --check: output never echoes settings values" "$INSTALL_OUT" "sentinel-value"

    install_fixture
    mkdir -p "$h/.claude/rules/kit"
    run_install
    assert_has "install: a real rules/kit directory is not replaced" "$INSTALL_OUT" "is not a symlink"
}
