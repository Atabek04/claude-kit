#!/bin/bash
# Fails when a tracked or untracked-but-unignored file holds an absolute home path, an email address or a
# token-shaped string. Usage: check-publishable.sh [repo-root]. Hits print as path:line: kind (tokens are redacted).
set -u

ROOT="${1:-.}"
cd "$ROOT" || exit 2
git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "check-publishable: $ROOT is not a git repository" >&2
    exit 2
}

# Only what the tests and docs need: the SSH clone URL, RFC 2606 example domains, and the attribution address
# the commit-msg gate rejects.
EMAIL_ALLOW_RE='^(git@github\.com|[A-Za-z0-9._%+-]+@example\.(com|org|net)|noreply@anthropic\.com)$'

HOME_PATH_RE='/(Users|home)/[A-Za-z0-9_][A-Za-z0-9._-]*'
EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
TOKEN_RES=(
    'gh[pousr]_[A-Za-z0-9]{36,}'
    'github_pat_[A-Za-z0-9_]{22,}'
    'sk-ant-[A-Za-z0-9_-]{20,}'
    'sk-[A-Za-z0-9]{32,}'
    'AKIA[0-9A-Z]{16}'
    'xox[abprs]-[A-Za-z0-9-]{10,}'
    'AIza[0-9A-Za-z_-]{35}'
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
    "(token|secret|passwd|password|api[_-]?key)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9/+_=-]{20,}[\"']"
)

FILES=$(mktemp)
HITS=$(mktemp)
trap 'rm -f "$FILES" "$HITS"' EXIT
git ls-files -z --cached --others --exclude-standard > "$FILES"
[ -s "$FILES" ] || exit 0

scan() {
    local kind=$1 regex=$2 hit path rest line match
    while IFS= read -r hit; do
        path=${hit%%:*}
        rest=${hit#*:}
        line=${rest%%:*}
        match=${rest#*:}
        if [ "$kind" = email ] && printf '%s' "$match" | grep -qE "$EMAIL_ALLOW_RE"; then
            continue
        fi
        case $kind in
            token) printf '%s:%s: token-shaped string (redacted)\n' "$path" "$line" ;;
            *) printf '%s:%s: %s: %s\n' "$path" "$line" "$kind" "$match" ;;
        esac
    done < <(xargs -0 grep -InoE -s -e "$regex" -- < "$FILES" 2> /dev/null) >> "$HITS"
}

scan home-path "$HOME_PATH_RE"
scan email "$EMAIL_RE"
for regex in "${TOKEN_RES[@]}"; do
    scan token "$regex"
done

if [ -s "$HITS" ]; then
    sort -u "$HITS"
    printf 'check-publishable: %s hits\n' "$(sort -u "$HITS" | wc -l | tr -d ' ')" >&2
    exit 1
fi
exit 0
