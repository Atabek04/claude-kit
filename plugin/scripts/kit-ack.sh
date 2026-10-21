#!/bin/bash
# Records the kit HEAD as this device's reviewed checkpoint. Run only after the user accepted the diff.

KIT="${CLAUDE_KIT:-$HOME/claude-kit}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

head=$(git -C "$KIT" rev-parse HEAD 2> /dev/null) || { echo "kit-ack: $KIT is not a git clone" >&2; exit 1; }
mkdir -p "$CLAUDE_DIR"
printf '%s\n' "$head" > "$CLAUDE_DIR/kit-seen"
echo "kit-ack: checkpoint ${head:0:7}"
