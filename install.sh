#!/bin/bash
# Idempotent machine setup for claude-kit. Usage: install.sh [--check]
# --check changes nothing and reports each step as ok, todo or warn; it exits 1 when a step is todo.
set -u

REPO_SLUG=Atabek04/claude-kit
MARKETPLACE=claude-kit
PLUGIN=kit
KIT="${CLAUDE_KIT:-$HOME/claude-kit}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SELF_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)

CHECK=0
TODO=0
FAILED=0
KIT_READY=0

case "${1:-}" in
    "") ;;
    --check) CHECK=1 ;;
    -h | --help)
        sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "install: unknown argument $1 (usage: install.sh [--check])" >&2
        exit 2
        ;;
esac

ok() { printf '  ok    %s\n' "$1"; }
warn() { printf '  warn  %s\n' "$1"; }
fail() {
    FAILED=$((FAILED + 1))
    printf '  FAIL  %s\n' "$1"
}
changed() { printf '  done  %s\n' "$1"; }

# Returns 0 when the caller should make the change; in --check it only reports and returns 1.
needs() {
    if [ "$CHECK" -eq 1 ]; then
        TODO=$((TODO + 1))
        printf '  todo  %s\n' "$1"
        return 1
    fi
    return 0
}

private_repo_hint() {
    echo "        if the repository is private: gh auth login && gh auth setup-git"
}

step_prerequisites() {
    local tool missing=0
    echo "Prerequisites"
    for tool in git jq gh; do
        if command -v "$tool" > /dev/null 2>&1; then
            ok "$tool found"
        else
            missing=1
            if [ "$CHECK" -eq 1 ]; then
                TODO=$((TODO + 1))
                printf '  todo  %s is not installed\n' "$tool"
            else
                fail "$tool is not installed"
            fi
        fi
    done
    if command -v claude > /dev/null 2>&1; then
        ok "claude found"
    else
        warn "claude is not on PATH; the plugin steps are skipped"
    fi
    if [ "$missing" -eq 1 ] && [ "$CHECK" -eq 0 ]; then
        echo "install: install the missing tools and run again" >&2
        exit 1
    fi
}

step_clone() {
    local clone_cmd
    echo "Clone"
    if git -C "$KIT" rev-parse --git-dir > /dev/null 2>&1; then
        KIT_READY=1
        ok "clone at $KIT"
        if [ "$SELF_DIR" != "$(cd -P "$KIT" && pwd)" ]; then
            warn "this install.sh runs from $SELF_DIR, not from the clone; the clone at $KIT is what hooks use"
        fi
        if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes -o ConnectTimeout=8" \
            git -C "$KIT" ls-remote --exit-code origin HEAD > /dev/null 2>&1; then
            warn "git cannot reach origin of $KIT"
            private_repo_hint
        fi
        return
    fi
    if [ -e "$KIT" ]; then
        warn "$KIT exists and is not a git clone; move it aside and run again"
        return
    fi
    needs "clone $REPO_SLUG to $KIT" || return
    if [ -n "${CLAUDE_KIT_REMOTE:-}" ]; then
        clone_cmd=(git clone --quiet "$CLAUDE_KIT_REMOTE" "$KIT")
    else
        clone_cmd=(gh repo clone "$REPO_SLUG" "$KIT" -- --quiet)
    fi
    if "${clone_cmd[@]}" > /dev/null 2>&1; then
        KIT_READY=1
        changed "cloned $REPO_SLUG to $KIT"
    else
        fail "could not clone $REPO_SLUG to $KIT"
        private_repo_hint
    fi
}

step_import() {
    local file="$CLAUDE_DIR/CLAUDE.md" line tmp
    line="@~/claude-kit/CLAUDE.md"
    [ "$KIT" = "$HOME/claude-kit" ] || line="@$KIT/CLAUDE.md"
    echo "Global CLAUDE.md import"
    if grep -qxF "$line" "$file" 2> /dev/null; then
        ok "$file imports the kit rules"
        return
    fi
    needs "add '$line' at the top of $file" || return
    mkdir -p "$CLAUDE_DIR"
    if [ -s "$file" ]; then
        tmp=$(mktemp "$CLAUDE_DIR/CLAUDE.md.XXXXXX")
        { printf '%s\n\n' "$line"; cat "$file"; } > "$tmp"
        if [ -L "$file" ]; then
            cat "$tmp" > "$file"
            rm -f "$tmp"
        else
            mv "$tmp" "$file"
        fi
    else
        printf '%s\n' "$line" > "$file"
    fi
    changed "added the import to $file"
}

step_rules_link() {
    local target="$KIT/rules" link="$CLAUDE_DIR/rules/kit"
    echo "Rules link"
    if [ ! -d "$target" ]; then
        if [ "$KIT_READY" -eq 1 ] || [ "$CHECK" -eq 1 ]; then
            if needs "create $target with a .gitkeep (commit it)"; then
                mkdir -p "$target"
                : > "$target/.gitkeep"
                changed "created $target with a .gitkeep; commit it"
            fi
        fi
    else
        ok "$target exists"
    fi
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        ok "$link -> $target"
    elif [ -L "$link" ]; then
        needs "repoint $link from $(readlink "$link") to $target" || return
        ln -sfn "$target" "$link"
        changed "repointed $link to $target"
    elif [ -e "$link" ]; then
        warn "$link exists and is not a symlink; move it aside and run again"
    else
        needs "link $link to $target" || return
        mkdir -p "$CLAUDE_DIR/rules"
        ln -s "$target" "$link"
        changed "linked $link to $target"
    fi
}

step_plugin() {
    local listing
    echo "Plugin"
    if ! command -v claude > /dev/null 2>&1; then
        warn "claude is not on PATH; skipped"
        return
    fi

    listing=$(claude plugin marketplace list --json 2> /dev/null)
    if ! printf '%s' "$listing" | jq -e . > /dev/null 2>&1; then
        warn "could not read the marketplace list from claude; skipped"
        return
    fi
    if printf '%s' "$listing" | jq -e --arg name "$MARKETPLACE" 'any(.[]; .name == $name)' > /dev/null 2>&1; then
        ok "marketplace $MARKETPLACE added"
    elif needs "claude plugin marketplace add $REPO_SLUG"; then
        if claude plugin marketplace add "$REPO_SLUG" > /dev/null 2>&1; then
            changed "added marketplace $MARKETPLACE"
        else
            fail "claude plugin marketplace add $REPO_SLUG failed"
            private_repo_hint
            return
        fi
    fi

    listing=$(claude plugin list --json 2> /dev/null)
    if ! printf '%s' "$listing" | jq -e . > /dev/null 2>&1; then
        warn "could not read the plugin list from claude; skipped"
        return
    fi
    if printf '%s' "$listing" | jq -e --arg id "$PLUGIN@$MARKETPLACE" 'any(.[]; .id == $id)' > /dev/null 2>&1; then
        ok "plugin $PLUGIN@$MARKETPLACE installed"
    elif needs "claude plugin install $PLUGIN@$MARKETPLACE"; then
        if claude plugin install "$PLUGIN@$MARKETPLACE" > /dev/null 2>&1; then
            changed "installed $PLUGIN@$MARKETPLACE"
        else
            fail "claude plugin install $PLUGIN@$MARKETPLACE failed"
        fi
    fi
}

step_auto_update() {
    local settings="$CLAUDE_DIR/settings.json" current tmp
    echo "Marketplace auto-update"
    if [ -f "$settings" ] && ! jq -e . "$settings" > /dev/null 2>&1; then
        warn "$settings is not valid JSON; auto-update left alone"
        return
    fi
    current=false
    if [ -f "$settings" ]; then
        current=$(jq -r --arg name "$MARKETPLACE" '.extraKnownMarketplaces[$name].autoUpdate // false' "$settings")
    fi
    if [ "$current" = true ]; then
        ok "autoUpdate is on for $MARKETPLACE in $settings"
        return
    fi
    needs "set autoUpdate for $MARKETPLACE in $settings (or toggle it under /plugin, Marketplaces)" || return
    mkdir -p "$CLAUDE_DIR"
    tmp=$(umask 077 && mktemp "$settings.XXXXXX")
    if { [ -f "$settings" ] && cat "$settings" || echo '{}'; } | jq --arg name "$MARKETPLACE" --arg repo "$REPO_SLUG" '
            .extraKnownMarketplaces = (.extraKnownMarketplaces // {})
            | .extraKnownMarketplaces[$name] =
                ((.extraKnownMarketplaces[$name] // {source: {source: "github", repo: $repo}}) + {autoUpdate: true})
        ' > "$tmp" && jq -e . "$tmp" > /dev/null 2>&1; then
        chmod 600 "$tmp"
        mv "$tmp" "$settings"
        changed "enabled autoUpdate for $MARKETPLACE in $settings"
    else
        rm -f "$tmp"
        fail "could not update $settings; enable auto-update under /plugin, Marketplaces"
    fi
}

step_shell() {
    local line="source ~/claude-kit/shell/bulk-edit.zsh"
    [ "$KIT" = "$HOME/claude-kit" ] || line="source $KIT/shell/bulk-edit.zsh"
    echo "Shell"
    if grep -qF 'shell/bulk-edit.zsh' "$ZSHRC" 2> /dev/null; then
        ok "$ZSHRC sources bulk-edit"
        return
    fi
    needs "append '$line' to $ZSHRC" || return
    printf '\n%s\n' "$line" >> "$ZSHRC"
    changed "appended the bulk-edit source line to $ZSHRC"
}

step_github_auth() {
    echo "GitHub access"
    if ! command -v gh > /dev/null 2>&1; then
        warn "gh is not installed; skipped"
        return
    fi
    if gh auth token > /dev/null 2>&1; then
        ok "gh is authenticated"
    else
        warn "gh is not authenticated"
        printf '        run: gh auth login && gh auth setup-git\n'
    fi
}

main() {
    if [ "$CHECK" -eq 1 ]; then echo "claude-kit install check (nothing is changed)"; else echo "claude-kit install"; fi
    step_prerequisites
    step_clone
    step_import
    step_rules_link
    step_plugin
    step_auto_update
    step_shell
    step_github_auth
    echo
    if [ "$CHECK" -eq 1 ]; then
        if [ "$TODO" -eq 0 ]; then
            echo "Nothing to do."
        else
            echo "$TODO steps to do. Run ./install.sh to apply them."
            exit 1
        fi
    elif [ "$FAILED" -gt 0 ]; then
        echo "$FAILED steps failed."
        exit 1
    else
        echo "Done. Start a new Claude Code session to load the rules."
    fi
}

main
