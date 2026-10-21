#!/bin/bash
# GitLab merge-request review helper: post inline findings, list and answer threads, post the overview.
# Usage: mr-review.sh <refs|threads|post|reply|resolve|note> <iid> [args]. Needs bash, curl, jq, git.
# Auth: GITLAB_TOKEN. Host and project come from the origin remote; GITLAB_URL and GITLAB_PROJECT override.
set -u

die() {
    printf 'mr-review: %s\n' "$1" >&2
    exit 1
}

command -v jq > /dev/null || die "jq is required"
[ -n "${GITLAB_TOKEN:-}" ] || die "GITLAB_TOKEN is not set"

remote_parts() {
    local url path host
    url=$(git remote get-url origin 2> /dev/null) || die "no origin remote and no GITLAB_URL/GITLAB_PROJECT"
    case $url in
        git@*:*) host=${url#git@}; host=${host%%:*}; path=${url#*:} ;;
        ssh://*) host=${url#ssh://}; host=${host#*@}; path=${host#*/}; host=${host%%/*} ;;
        http*://*) host=${url#*://}; host=${host#*@}; path=${host#*/}; host=${host%%/*} ;;
        *) die "cannot parse origin remote" ;;
    esac
    printf '%s %s\n' "$host" "${path%.git}"
}

if [ -z "${GITLAB_URL:-}" ] || [ -z "${GITLAB_PROJECT:-}" ]; then
    read -r REMOTE_HOST REMOTE_PATH < <(remote_parts)
fi
BASE="${GITLAB_URL:-https://$REMOTE_HOST}/api/v4/projects/$(printf '%s' "${GITLAB_PROJECT:-$REMOTE_PATH}" | sed 's|/|%2F|g')"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
STATUS=0

# api METHOD PATH [JSON-FILE]: body lands in $TMP/out, HTTP status in $STATUS; never prints the token.
api() {
    local method=$1 path=$2 data=${3:-}
    local args=(-sS -X "$method" -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -o "$TMP/out" -w '%{http_code}')
    [ -n "$data" ] && args+=(-H 'Content-Type: application/json' --data "@$data")
    STATUS=$(curl "${args[@]}" "$BASE$path") || die "request failed: $method $path"
}

need_ok() {
    case $STATUS in
        2??) ;;
        *) die "$1 failed with HTTP $STATUS: $(jq -r '.message // .error // .' "$TMP/out" 2> /dev/null | head -c 300)" ;;
    esac
}

iid_arg() {
    case ${1:-} in
        '' | *[!0-9]*) die "merge request number must be digits" ;;
    esac
}

cmd_refs() {
    api GET "/merge_requests/$1"
    need_ok "read merge request"
    jq '{iid, title, state, web_url, source: .source_branch, target: .target_branch, diff_refs}' "$TMP/out"
}

cmd_threads() {
    api GET "/merge_requests/$1/discussions?per_page=100"
    need_ok "list discussions"
    jq -r '.[] | select(.notes[0].system == false)
        | [.id, .notes[0].id, (.notes[0].resolved // false | tostring),
           ((.notes[0].position.new_path // "-") + ":" + ((.notes[0].position.new_line // "-") | tostring)),
           (.notes[0].body | split("\n")[0] | .[0:100])] | @tsv' "$TMP/out"
}

# post IID FINDINGS.json: [{"path","line","body"}], line on the new side of the diff. A line outside the diff is
# posted as a plain thread with path:line in the body, so no finding is lost.
cmd_post() {
    local findings=${2:-} refs n i path line payload
    [ -f "$findings" ] || die "findings file not found"
    api GET "/merge_requests/$1"
    need_ok "read merge request"
    refs=$(jq -c '.diff_refs' "$TMP/out")
    [ "$refs" != null ] || die "merge request has no diff_refs yet"
    n=$(jq 'length' "$findings")
    for ((i = 0; i < n; i++)); do
        path=$(jq -r ".[$i].path" "$findings")
        line=$(jq -r ".[$i].line" "$findings")
        jq --argjson refs "$refs" ".[$i] | {body, position: {position_type: \"text\", base_sha: \$refs.base_sha,
            start_sha: \$refs.start_sha, head_sha: \$refs.head_sha, old_path: .path, new_path: .path, new_line: .line}}" \
            "$findings" > "$TMP/payload.json"
        api POST "/merge_requests/$1/discussions" "$TMP/payload.json"
        case $STATUS in
            2??) printf '%s\t%s:%s\tinline\n' "$(jq -r .id "$TMP/out")" "$path" "$line" ;;
            400)
                jq ".[$i] | {body: (\"\`\" + .path + \":\" + (.line | tostring) + \"\`\\n\\n\" + .body)}" "$findings" > "$TMP/payload.json"
                api POST "/merge_requests/$1/discussions" "$TMP/payload.json"
                need_ok "post finding $path:$line"
                printf '%s\t%s:%s\tplain\n' "$(jq -r .id "$TMP/out")" "$path" "$line"
                ;;
            *) need_ok "post finding $path:$line" ;;
        esac
    done
}

body_payload() {
    [ -f "${1:-}" ] || die "body file not found"
    jq -n --rawfile body "$1" '{body: $body}' > "$TMP/payload.json"
}

cmd_reply() {
    case ${2:-} in '' | *[!0-9a-f]*) die "discussion id must be hex" ;; esac
    body_payload "${3:-}"
    api POST "/merge_requests/$1/discussions/$2/notes" "$TMP/payload.json"
    need_ok "reply"
    jq -r '"reply " + (.id | tostring)' "$TMP/out"
}

cmd_resolve() {
    case ${2:-} in '' | *[!0-9a-f]*) die "discussion id must be hex" ;; esac
    printf '{"resolved":true}' > "$TMP/payload.json"
    api PUT "/merge_requests/$1/discussions/$2" "$TMP/payload.json"
    need_ok "resolve"
    printf 'resolved %s\n' "$2"
}

cmd_note() {
    body_payload "${2:-}"
    api POST "/merge_requests/$1/notes" "$TMP/payload.json"
    need_ok "note"
    jq -r '"note " + (.id | tostring)' "$TMP/out"
}

CMD=${1:-}
iid_arg "${2:-}"
case $CMD in
    refs) cmd_refs "$2" ;;
    threads) cmd_threads "$2" ;;
    post) cmd_post "$2" "${3:-}" ;;
    reply) cmd_reply "$2" "${3:-}" "${4:-}" ;;
    resolve) cmd_resolve "$2" "${3:-}" ;;
    note) cmd_note "$2" "${3:-}" ;;
    *) die "usage: mr-review.sh <refs|threads|post|reply|resolve|note> <iid> [args]" ;;
esac
