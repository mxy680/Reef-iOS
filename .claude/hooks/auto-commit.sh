#!/bin/bash

# Read hook input from stdin
INPUT=$(cat)

# Extract tool name and file path
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Check if there are changes to commit
if git diff --quiet && git diff --cached --quiet; then
  exit 0
fi

# Get just the filename
FILENAME=$(basename "$FILE_PATH")

# Get the relative path from project root
REL_PATH=$(echo "$FILE_PATH" | sed "s|$CLAUDE_PROJECT_DIR/||")

# Generate commit message based on tool and file
case "$TOOL_NAME" in
  "Write")
    MSG="Create $REL_PATH"
    ;;
  "Edit")
    MSG="Update $REL_PATH"
    ;;
  *)
    MSG="Modify $REL_PATH"
    ;;
esac

git add "$FILE_PATH"
git commit -m "$MSG" --quiet 2>/dev/null || true

exit 0
