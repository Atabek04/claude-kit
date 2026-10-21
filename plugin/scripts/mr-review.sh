#!/bin/bash
# Review helper for GitLab merge requests and GitHub pull requests: refs, threads, post, reply, resolve, note.
# Provider from origin (github.com is GitHub, else GitLab; REVIEW_PROVIDER overrides). Needs jq and curl or gh.
# GitLab: GITLAB_TOKEN, optional GITLAB_URL and GITLAB_PROJECT. GitHub: gh login, optional GITHUB_REPOSITORY.
set -u

die() {
    printf 'mr-review: %s\n' "$1" >&2
    exit 1
}

command -v jq > /dev/null || die "jq is required"

REMOTE_HOST="" REMOTE_PATH=""
if URL=$(git remote get-url origin 2> /dev/null); then
    case $URL in
        git@*:*) REMOTE_HOST=${URL#git@}; REMOTE_HOST=${REMOTE_HOST%%:*}; REMOTE_PATH=${URL#*:} ;;
        ssh://*) REMOTE_HOST=${URL#ssh://}; REMOTE_HOST=${REMOTE_HOST#*@}; REMOTE_PATH=${REMOTE_HOST#*/}; REMOTE_HOST=${REMOTE_HOST%%/*} ;;
        http*://*) REMOTE_HOST=${URL#*://}; REMOTE_HOST=${REMOTE_HOST#*@}; REMOTE_PATH=${REMOTE_HOST#*/}; REMOTE_HOST=${REMOTE_HOST%%/*} ;;
    esac
    REMOTE_PATH=${REMOTE_PATH%.git}
fi

PROVIDER=${REVIEW_PROVIDER:-}
if [ -z "$PROVIDER" ]; then
    case $REMOTE_HOST in github.com) PROVIDER=github ;; *) PROVIDER=gitlab ;; esac
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
STATUS=0

if [ "$PROVIDER" = github ]; then
    command -v gh > /dev/null || die "gh is required for GitHub"
    SLUG=${GITHUB_REPOSITORY:-$REMOTE_PATH}
    [ -n "$SLUG" ] || die "no origin remote and no GITHUB_REPOSITORY"
else
    [ -n "${GITLAB_TOKEN:-}" ] || die "GITLAB_TOKEN is not set"
    PROJECT=${GITLAB_PROJECT:-$REMOTE_PATH}
    HOST=${GITLAB_URL:-${REMOTE_HOST:+https://$REMOTE_HOST}}
    [ -n "$PROJECT" ] && [ -n "$HOST" ] || die "no origin remote and no GITLAB_URL/GITLAB_PROJECT"
    BASE="$HOST/api/v4/projects/$(printf '%s' "$PROJECT" | sed 's|/|%2F|g')"
fi

# api METHOD PATH [JSON-FILE]: body lands in $TMP/out, the HTTP status in $STATUS; never prints a token.
api() {
    local method=$1 path=$2 data=${3:-}
    if [ "$PROVIDER" = github ]; then
        local args=(api -X "$method" "repos/$SLUG$path")
        [ -n "$data" ] && args+=(--input "$data")
        if gh "${args[@]}" > "$TMP/out" 2> "$TMP/err"; then
            STATUS=200
        else
            STATUS=$(grep -oE 'HTTP [0-9]{3}' "$TMP/err" | head -1 | cut -d' ' -f2)
            STATUS=${STATUS:-500}
        fi
        return
    fi
    local cargs=(-sS -X "$method" -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -o "$TMP/out" -w '%{http_code}')
    [ -n "$data" ] && cargs+=(-H 'Content-Type: application/json' --data "@$data")
    STATUS=$(curl "${cargs[@]}" "$BASE$path") || die "request failed: $method $path"
}

# graphql QUERY [gh -f/-F args...]: GitHub only; response in $TMP/out.
graphql() {
    local query=$1
    shift
    if gh api graphql -f "query=$query" "$@" > "$TMP/out" 2> "$TMP/err"; then STATUS=200; else STATUS=500; fi
}

need_ok() {
    case $STATUS in
        2??) ;;
        *) die "$1 failed with HTTP $STATUS: $( (jq -r '.message // .error // .' "$TMP/out" 2> /dev/null; cat "$TMP/err" 2> /dev/null) | head -c 300)" ;;
    esac
}

iid_arg() {
    case ${1:-} in
        '' | *[!0-9]*) die "merge request number must be digits" ;;
    esac
}

hex_arg() {
    case ${1:-} in
        '' | *[!0-9a-f]*) die "thread id must be hex or digits" ;;
    esac
}

cmd_refs() {
    if [ "$PROVIDER" = github ]; then
        api GET "/pulls/$1"
        need_ok "read pull request"
        jq '{iid: .number, title, state, web_url: .html_url, source: .head.ref, target: .base.ref,
             diff_refs: {base_sha: .base.sha, start_sha: .base.sha, head_sha: .head.sha}}' "$TMP/out"
        return
    fi
    api GET "/merge_requests/$1"
    need_ok "read merge request"
    jq '{iid, title, state, web_url, source: .source_branch, target: .target_branch, diff_refs}' "$TMP/out"
}

cmd_threads() {
    if [ "$PROVIDER" = github ]; then
        graphql 'query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved comments(first:1){nodes{databaseId body path line}}}}}}}' \
            -f "o=${SLUG%%/*}" -f "r=${SLUG#*/}" -F "n=$1"
        need_ok "list review threads"
        jq -r '.data.repository.pullRequest.reviewThreads.nodes[] | .comments.nodes[0] as $c
            | [($c.databaseId | tostring), ($c.databaseId | tostring), (if .isResolved then "true" else "false" end),
               (($c.path // "-") + ":" + (($c.line // "-") | tostring)), ($c.body | split("\n")[0] | .[0:100])] | @tsv' "$TMP/out"
        return
    fi
    api GET "/merge_requests/$1/discussions?per_page=100"
    need_ok "list discussions"
    jq -r '.[] | select(.notes[0].system == false)
        | [.id, .notes[0].id, (.notes[0].resolved // false | tostring),
           ((.notes[0].position.new_path // "-") + ":" + ((.notes[0].position.new_line // "-") | tostring)),
           (.notes[0].body | split("\n")[0] | .[0:100])] | @tsv' "$TMP/out"
}

plain_payload() {
    jq ".[$2] | {body: (\"\`\" + .path + \":\" + (.line | tostring) + \"\`\\n\\n\" + .body)}" "$1" > "$TMP/payload.json"
}

# post NUMBER FINDINGS.json: [{"path","line","body"}], line on the new side of the diff. A line outside the diff is
# posted as a plain comment with path:line in the body, so no finding is lost.
cmd_post() {
    local findings=${2:-} refs head n i path line
    [ -f "$findings" ] || die "findings file not found"
    cmd_refs "$1" > "$TMP/refs.json"
    refs=$(jq -c '.diff_refs' "$TMP/refs.json")
    [ "$refs" != null ] || die "the change has no diff_refs yet"
    head=$(jq -r '.head_sha' <<< "$refs")
    n=$(jq 'length' "$findings")
    for ((i = 0; i < n; i++)); do
        path=$(jq -r ".[$i].path" "$findings")
        line=$(jq -r ".[$i].line" "$findings")
        if [ "$PROVIDER" = github ]; then
            jq --arg head "$head" ".[$i] | {body, commit_id: \$head, path, line, side: \"RIGHT\"}" "$findings" > "$TMP/payload.json"
            api POST "/pulls/$1/comments" "$TMP/payload.json"
            case $STATUS in
                2??) printf '%s\t%s:%s\tinline\n' "$(jq -r .id "$TMP/out")" "$path" "$line" ;;
                422)
                    plain_payload "$findings" "$i"
                    api POST "/issues/$1/comments" "$TMP/payload.json"
                    need_ok "post finding $path:$line"
                    printf '%s\t%s:%s\tplain\n' "$(jq -r .id "$TMP/out")" "$path" "$line"
                    ;;
                *) need_ok "post finding $path:$line" ;;
            esac
            continue
        fi
        jq --argjson refs "$refs" ".[$i] | {body, position: {position_type: \"text\", base_sha: \$refs.base_sha,
            start_sha: \$refs.start_sha, head_sha: \$refs.head_sha, old_path: .path, new_path: .path, new_line: .line}}" \
            "$findings" > "$TMP/payload.json"
        api POST "/merge_requests/$1/discussions" "$TMP/payload.json"
        case $STATUS in
            2??) printf '%s\t%s:%s\tinline\n' "$(jq -r .id "$TMP/out")" "$path" "$line" ;;
            400)
                plain_payload "$findings" "$i"
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
    hex_arg "${2:-}"
    body_payload "${3:-}"
    if [ "$PROVIDER" = github ]; then
        api POST "/pulls/$1/comments/$2/replies" "$TMP/payload.json"
    else
        api POST "/merge_requests/$1/discussions/$2/notes" "$TMP/payload.json"
    fi
    need_ok "reply"
    jq -r '"reply " + (.id | tostring)' "$TMP/out"
}

cmd_resolve() {
    hex_arg "${2:-}"
    if [ "$PROVIDER" = github ]; then
        local node
        graphql 'query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{id comments(first:1){nodes{databaseId}}}}}}}' \
            -f "o=${SLUG%%/*}" -f "r=${SLUG#*/}" -F "n=$1"
        need_ok "list review threads"
        node=$(jq -r --argjson c "$2" '.data.repository.pullRequest.reviewThreads.nodes[]
            | select(.comments.nodes[0].databaseId == $c) | .id' "$TMP/out")
        [ -n "$node" ] || die "no review thread with root comment $2"
        graphql 'mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}' -f "t=$node"
        need_ok "resolve"
        printf 'resolved %s\n' "$2"
        return
    fi
    printf '{"resolved":true}' > "$TMP/payload.json"
    api PUT "/merge_requests/$1/discussions/$2" "$TMP/payload.json"
    need_ok "resolve"
    printf 'resolved %s\n' "$2"
}

cmd_note() {
    body_payload "${2:-}"
    if [ "$PROVIDER" = github ]; then
        api POST "/issues/$1/comments" "$TMP/payload.json"
    else
        api POST "/merge_requests/$1/notes" "$TMP/payload.json"
    fi
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
    *) die "usage: mr-review.sh <refs|threads|post|reply|resolve|note> <number> [args]" ;;
esac
