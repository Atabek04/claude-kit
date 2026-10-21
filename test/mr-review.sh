#!/bin/bash
# shellcheck disable=SC2154
# Cases for plugin/scripts/mr-review.sh against a stub curl (GitLab) and a stub gh (GitHub). Sourced by run.sh, which
# provides ROOT, WORK, new_repo and the assert helpers.

MR_SCRIPT="$ROOT/plugin/scripts/mr-review.sh"

mr_stub_curl() {
    cat > "$1/bin/curl" << 'STUB'
#!/bin/bash
method=GET out="" data="" url=""
while [ $# -gt 0 ]; do
    case $1 in
        -X) method=$2; shift ;;
        -o) out=$2; shift ;;
        --data) data=${2#@}; shift ;;
        -H | -w) shift ;;
        -*) ;;
        *) url=$1 ;;
    esac
    shift
done
{ printf '%s %s\n' "$method" "$url"; [ -n "$data" ] && cat "$data" && echo; } >> "$STUB_LOG"
status=200 body='{}'
case "$method $url" in
    "GET "*/merge_requests/7) body='{"iid":7,"title":"t","state":"opened","web_url":"u","source_branch":"s","target_branch":"d","diff_refs":{"base_sha":"b1","start_sha":"s1","head_sha":"h1"}}' ;;
    "GET "*/discussions\?per_page=100) body='[{"id":"d1","notes":[{"id":11,"system":false,"resolved":false,"body":"issue (blocking): x\nmore","position":{"new_path":"a/B.kt","new_line":5}}]},{"id":"d2","notes":[{"id":12,"system":true,"body":"merged"}]}]' ;;
    "POST "*/merge_requests/7/discussions)
        if [ "${STUB_POSITION_FAIL:-}" = 1 ] && grep -q '"position"' "$data"; then
            status=400 body='{"message":"line_code can'"'"'t be blank"}'
        else
            status=201 body='{"id":"abc123"}'
        fi ;;
    "POST "*/discussions/*/notes) status=201 body='{"id":56}' ;;
    "POST "*/merge_requests/7/notes) status=201 body='{"id":55}' ;;
    "PUT "*/discussions/*) body='{"id":"d1"}' ;;
esac
printf '%s' "$body" > "$out"
printf '%s' "$status"
STUB
    chmod +x "$1/bin/curl"
}

mr_stub_gh() {
    cat > "$1/bin/gh" << 'STUB'
#!/bin/bash
shift
method=GET path="" data="" graphql="" qargs=""
if [ "$1" = graphql ]; then
    graphql=1
    shift
    qargs="$*"
else
    while [ $# -gt 0 ]; do
        case $1 in
            -X) method=$2; shift ;;
            --input) data=$2; shift ;;
            *) path=$1 ;;
        esac
        shift
    done
fi
{ if [ -n "$graphql" ]; then printf 'GRAPHQL %s\n' "$qargs"; else printf '%s %s\n' "$method" "$path"; fi; [ -n "$data" ] && cat "$data" && echo; } >> "$STUB_LOG"
if [ -n "$graphql" ]; then
    case $qargs in
        *resolveReviewThread*) echo '{"data":{"resolveReviewThread":{"thread":{"isResolved":true}}}}' ;;
        *"nodes{id comments"*) echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"PRRT_x","comments":{"nodes":[{"databaseId":901}]}}]}}}}}' ;;
        *) echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":false,"comments":{"nodes":[{"databaseId":901,"body":"issue (blocking): x\nmore","path":"a/B.kt","line":5}]}}]}}}}}' ;;
    esac
    exit 0
fi
case "$method $path" in
    "GET repos/"*/pulls/7) echo '{"number":7,"title":"t","state":"open","html_url":"u","head":{"ref":"s","sha":"h1"},"base":{"ref":"d","sha":"b1"}}' ;;
    "POST repos/"*/pulls/7/comments)
        if [ "${STUB_INLINE_FAIL:-}" = 1 ]; then echo 'gh: Validation Failed (HTTP 422)' >&2; echo '{"message":"Validation Failed"}'; exit 1; fi
        echo '{"id":901}' ;;
    "POST repos/"*/pulls/7/comments/901/replies) echo '{"id":903}' ;;
    "POST repos/"*/issues/7/comments) echo '{"id":902}' ;;
    *) echo '{}' ;;
esac
STUB
    chmod +x "$1/bin/gh"
}

mr_fixture() {
    local d="$WORK/mr"
    rm -rf "$d"
    mkdir -p "$d/bin"
    mr_stub_curl "$d"
    mr_stub_gh "$d"
    new_repo "$d/repo"
    git -C "$d/repo" remote add origin https://git.example.com/team/sub/proj.git
    printf '[{"path":"src/A.kt","line":12,"body":"issue (blocking): boom"}]\n' > "$d/findings.json"
    printf 'Fixed in abc.\n' > "$d/body.md"
}

mr_run() {
    local d="$WORK/mr"
    : > "$d/log"
    (cd "$d/repo" && PATH="$d/bin:$PATH" STUB_LOG="$d/log" GITLAB_TOKEN="${TOKEN-secret}" bash "$MR_SCRIPT" "$@" 2>&1)
}

run_mr_review_cases() {
    mr_fixture
    local d="$WORK/mr" out

    out=$(mr_run refs 7)
    assert_has "mr-review refs shows diff_refs" "$out" '"head_sha": "h1"'
    assert_has "mr-review encodes project path and uses origin host" "$(cat "$d/log")" \
        'GET https://git.example.com/api/v4/projects/team%2Fsub%2Fproj/merge_requests/7'

    out=$(mr_run post 7 "$d/findings.json")
    assert_has "mr-review post inline reports the discussion" "$out" "abc123	src/A.kt:12	inline"
    assert_has "mr-review post sends the position on the new side" "$(cat "$d/log")" '"new_line": 12'
    assert_has "mr-review post sends the three shas" "$(cat "$d/log")" '"start_sha": "s1"'

    out=$(STUB_POSITION_FAIL=1 mr_run post 7 "$d/findings.json")
    assert_has "mr-review post falls back to a plain thread" "$out" "plain"
    assert_has "mr-review fallback body names path:line" "$(tail -n 3 "$d/log")" 'src/A.kt:12'
    assert_lacks "mr-review fallback body has no position" "$(tail -n 2 "$d/log")" '"position"'

    out=$(mr_run reply 7 d1 "$d/body.md")
    assert_has "mr-review reply posts into the thread" "$out" "reply 56"
    assert_has "mr-review reply uses the discussion notes path" "$(cat "$d/log")" 'POST https://git.example.com/api/v4/projects/team%2Fsub%2Fproj/merge_requests/7/discussions/d1/notes'
    assert_has "mr-review reply sends the file text" "$(cat "$d/log")" 'Fixed in abc.'

    out=$(mr_run reply 7 'd1;rm' "$d/body.md")
    assert_has "mr-review rejects a non-hex thread id" "$out" "thread id must be hex or digits"

    out=$(mr_run note 7 "$d/body.md")
    assert_has "mr-review note posts the overview" "$out" "note 55"

    out=$(mr_run resolve 7 d1)
    assert_has "mr-review resolve marks the thread" "$out" "resolved d1"

    out=$(mr_run threads 7)
    assert_has "mr-review threads lists id, path and first line" "$out" "d1	11	false	a/B.kt:5	issue (blocking): x"
    assert_lacks "mr-review threads skips system notes" "$out" "d2"

    out=$(mr_run refs 7x)
    assert_has "mr-review rejects a non-numeric merge request" "$out" "merge request number must be digits"

    out=$(TOKEN="" mr_run refs 7)
    assert_has "mr-review needs a token" "$out" "GITLAB_TOKEN is not set"
    assert_lacks "mr-review never prints the token" "$(mr_run refs 7)" "secret"

    git -C "$d/repo" remote set-url origin ssh://gitlab.example.org/team/proj.git
    mr_run refs 7 > /dev/null
    assert_has "mr-review parses an ssh remote" "$(cat "$d/log")" 'GET https://gitlab.example.org/api/v4/projects/team%2Fproj/merge_requests/7'

    run_mr_review_github_cases
}

run_mr_review_github_cases() {
    local d="$WORK/mr" out
    git -C "$d/repo" remote set-url origin git@github.com:team/proj.git

    out=$(mr_run refs 7)
    assert_has "mr-review github refs maps the pull request" "$out" '"head_sha": "h1"'
    assert_has "mr-review github picks gh from the origin host" "$(cat "$d/log")" 'GET repos/team/proj/pulls/7'

    out=$(mr_run post 7 "$d/findings.json")
    assert_has "mr-review github post is inline" "$out" "901	src/A.kt:12	inline"
    assert_has "mr-review github post pins the head commit and side" "$(cat "$d/log")" '"commit_id": "h1"'
    assert_has "mr-review github post uses the right side" "$(cat "$d/log")" '"side": "RIGHT"'

    out=$(STUB_INLINE_FAIL=1 mr_run post 7 "$d/findings.json")
    assert_has "mr-review github falls back to a plain comment" "$out" "902	src/A.kt:12	plain"

    out=$(mr_run threads 7)
    assert_has "mr-review github threads lists the root comment" "$out" "901	901	false	a/B.kt:5	issue (blocking): x"

    out=$(mr_run reply 7 901 "$d/body.md")
    assert_has "mr-review github reply" "$out" "reply 903"
    assert_has "mr-review github reply uses the replies path" "$(cat "$d/log")" 'POST repos/team/proj/pulls/7/comments/901/replies'

    out=$(mr_run resolve 7 901)
    assert_has "mr-review github resolve finds the thread" "$out" "resolved 901"
    assert_has "mr-review github resolve runs the mutation" "$(cat "$d/log")" 'resolveReviewThread'

    out=$(mr_run note 7 "$d/body.md")
    assert_has "mr-review github note posts an issue comment" "$out" "note 902"

    out=$(REVIEW_PROVIDER=gitlab TOKEN="" mr_run refs 7)
    assert_has "mr-review provider override reaches the gitlab branch" "$out" "GITLAB_TOKEN is not set"
}
