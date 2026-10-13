# Opens the bulk-edit gate checked by plugin/scripts/block-inplace-edits.sh in claude-kit.
# Run by the user only: `bulk-edit 30` allows scripted project edits for 30 minutes.
bulk-edit() {
    local minutes="${1:-30}"
    local gate="$HOME/.claude/bulk-edit.allow"
    case "$minutes" in
        off|close|0) rm -f "$gate"; echo "bulk-edit gate closed"; return ;;
        *[!0-9]*|'') echo "usage: bulk-edit <minutes>|off" >&2; return 1 ;;
    esac
    printf '%s\n' "$(( $(date +%s) + minutes * 60 ))" > "$gate"
    echo "bulk-edit gate open for ${minutes}m (until $(date -r "$(cat "$gate")" '+%H:%M'))"
}
