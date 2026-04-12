#!/bin/bash
set -e

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path')

if [[ "$FILE_PATH" == *.ex ]] || [[ "$FILE_PATH" == *.exs ]] || [[ "$FILE_PATH" == *.heex ]]; then
  cd "$CLAUDE_PROJECT_DIR"
  mix format "$FILE_PATH" 2>/dev/null || true
fi

exit 0
