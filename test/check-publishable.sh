#!/bin/bash
# shellcheck disable=SC2154
# Cases for scripts/check-publishable.sh. Sourced by run.sh, which provides ROOT, WORK, new_repo, gen_text and the
# assert helpers. Sensitive-looking strings are assembled at run time so this file stays publishable itself.

PUBLISHABLE="$ROOT/scripts/check-publishable.sh"

publishable() {
    PUBLISHABLE_OUT=$(cd "$1" && "$PUBLISHABLE" 2>&1)
    PUBLISHABLE_STATUS=$?
}

run_check_publishable_cases() {
    local d="$WORK/publishable" token home_path email
    token="ghp_$(gen_text a 36)"
    home_path="/Users/$(gen_text a 1)lice/project"
    email=$(printf '%s@%s.com' person company)

    new_repo "$d"
    printf 'plain text\nclone git@github.com:owner/repo.git\ncontact someone@example.com\n' > "$d/clean.md"
    git -C "$d" add -A
    publishable "$d"
    assert_eq "publishable: clean tree passes" "0" "$PUBLISHABLE_STATUS"
    assert_eq "publishable: clean tree prints nothing" "" "$PUBLISHABLE_OUT"

    printf 'see %s for details\n' "$home_path" > "$d/path.md"
    publishable "$d"
    assert_eq "publishable: a home path fails" "1" "$PUBLISHABLE_STATUS"
    assert_has "publishable: the home path is located" "$PUBLISHABLE_OUT" "path.md:1: home-path: ${home_path%/project}"
    rm "$d/path.md"

    printf 'paths are written as /home/<user> or /Users/<name> placeholders\n' > "$d/placeholder.md"
    publishable "$d"
    assert_eq "publishable: placeholder paths pass" "0" "$PUBLISHABLE_STATUS"
    rm "$d/placeholder.md"

    printf 'write to %s\n' "$(printf '/home/%s/x' bob)" > "$d/linux.md"
    publishable "$d"
    assert_has "publishable: a linux home path fails" "$PUBLISHABLE_OUT" "linux.md:1: home-path"
    rm "$d/linux.md"

    printf 'mail %s\n' "$email" > "$d/mail.md"
    publishable "$d"
    assert_eq "publishable: a real-looking email fails" "1" "$PUBLISHABLE_STATUS"
    assert_has "publishable: the email is located" "$PUBLISHABLE_OUT" "mail.md:1: email: $email"
    rm "$d/mail.md"

    printf 'key = %s\n' "$token" > "$d/token.md"
    publishable "$d"
    assert_eq "publishable: a token-shaped string fails" "1" "$PUBLISHABLE_STATUS"
    assert_has "publishable: the token is located" "$PUBLISHABLE_OUT" "token.md:1: token-shaped string (redacted)"
    assert_lacks "publishable: the token is not echoed" "$PUBLISHABLE_OUT" "$token"
    rm "$d/token.md"

    printf 'api_key = "%s"\n' "$(gen_text Ab3 8)" > "$d/assign.md"
    publishable "$d"
    assert_has "publishable: a quoted secret assignment fails" "$PUBLISHABLE_OUT" "assign.md:1: token-shaped string"
    rm "$d/assign.md"

    printf 'key = %s\n' "$token" > "$d/ignored.md"
    printf 'ignored.md\n' > "$d/.gitignore"
    git -C "$d" add -A
    publishable "$d"
    assert_eq "publishable: ignored files are not scanned" "0" "$PUBLISHABLE_STATUS"

    printf 'see %s\n' "$home_path" > "$d/untracked.md"
    publishable "$d"
    assert_has "publishable: untracked files are scanned" "$PUBLISHABLE_OUT" "untracked.md:1: home-path"

    local outside
    outside=$(mktemp -d)
    publishable "$outside"
    rmdir "$outside"
    assert_eq "publishable: a non-repository fails with 2" "2" "$PUBLISHABLE_STATUS"
}
