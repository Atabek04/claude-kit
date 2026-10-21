#!/bin/bash
# shellcheck disable=SC2154
# Cases for plugin/scripts/mr-review.sh against a stub curl. Sourced by run.sh, which provides ROOT, WORK, new_repo
# and the assert helpers.

MR_SCRIPT="$ROOT/plugin/scripts/mr-review.sh"

mr_fixture() {
    local d="$WORK/mr"
    rm -rf "$d"
    mkdir -p "$d/bin"
    cat > "$d/bin/curl" << 'STUB'
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
    chmod +x "$d/bin/curl"
    new_repo "$d/repo"
    git -C "$d/repo" remote add origin git@github.com:team/sub/proj.git
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
        'GET https://github.com/api/v4/projects/team%2Fsub%2Fproj/merge_requests/7'

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
    assert_has "mr-review reply uses the discussion notes path" "$(cat "$d/log")" 'POST https://github.com/api/v4/projects/team%2Fsub%2Fproj/merge_requests/7/discussions/d1/notes'
    assert_has "mr-review reply sends the file text" "$(cat "$d/log")" 'Fixed in abc.'

    out=$(mr_run reply 7 'd1;rm' "$d/body.md")
    assert_has "mr-review rejects a non-hex discussion id" "$out" "discussion id must be hex"

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

    git -C "$d/repo" remote set-url origin https://git.example.com/team/proj.git
    mr_run refs 7 > /dev/null
    assert_has "mr-review parses an https remote" "$(cat "$d/log")" 'GET https://git.example.com/api/v4/projects/team%2Fproj/merge_requests/7'
}
