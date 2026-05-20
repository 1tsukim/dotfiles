#!/bin/bash
# PreToolUse(Write|Edit) hook: 機密ファイルへの書き込みをブロック
# settings.json の deny (Write(.env*) 等) と二重防御の関係

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")

SENSITIVE_PATTERNS=(
  '^\.env$'
  '^\.env\..+'
  '.*credential.*'
  '.*secret.*'
  '.*password.*'
  '.*apikey.*'
  '.*api_key.*'
  '^id_rsa$'
  '^id_ed25519$'
  '^id_ecdsa$'
  '.*\.pem$'
  '.*\.key$'
  '.*\.p12$'
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
  if echo "$FILENAME" | grep -qiE "$pattern"; then
    echo "BLOCKED: '$FILE_PATH' matches sensitive file pattern '$pattern'. The user has prevented you from writing sensitive files." >&2
    exit 2
  fi
done

exit 0
