#!/bin/bash
# git commit-msg hook target: Conventional Commits subject, no AI attribution. Usage: commit-msg.sh <message-file>

MESSAGE_FILE="${1:-}"
if [ -z "$MESSAGE_FILE" ] || [ ! -f "$MESSAGE_FILE" ]; then
    echo "commit-msg: usage: commit-msg.sh <message-file>" >&2
    exit 2
fi

TYPES='feat|fix|test|refactor|docs|chore|perf|build|ci|style|revert'
SUBJECT_RE="^($TYPES)(\\([A-Za-z0-9._/,-]+\\))?!?: [^[:space:]]"
ROBOT=$(printf '\360\237\244\226')

MESSAGE=$(grep -v '^#' "$MESSAGE_FILE")
SUBJECT=$(printf '%s\n' "$MESSAGE" | grep -m1 '[^[:space:]]')

reject() {
    printf 'commit-msg: %s\n' "$1" >&2
    exit 1
}

if printf '%s\n' "$MESSAGE" | grep -qiE '^[[:space:]]*co-authored-by:.*(claude|anthropic)' \
    || printf '%s\n' "$MESSAGE" | grep -qiE 'generated with.*claude' \
    || printf '%s\n' "$MESSAGE" | grep -qF "$ROBOT"; then
    reject "AI attribution (Co-Authored-By naming Claude or Anthropic, 'Generated with Claude', the robot emoji) does not belong in a commit message."
fi

case "$SUBJECT" in
    "") exit 0 ;;
    "Merge "* | "fixup! "* | "squash! "* | "amend! "* | "Revert \""* | "Reapply \""*) exit 0 ;;
esac

if ! printf '%s\n' "$SUBJECT" | grep -qE "$SUBJECT_RE"; then
    reject "subject must be 'type(scope)!: description' with type one of $(printf '%s' "$TYPES" | tr '|' ' '). Got: $SUBJECT"
fi
exit 0
