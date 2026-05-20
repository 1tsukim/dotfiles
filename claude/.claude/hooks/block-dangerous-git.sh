#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

DANGEROUS_PATTERNS=(
  "git push"
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "push --force"
  "reset --hard"
  # 履歴改変系（reflog 削除 + gc で物理削除でコミット完全消去）
  "git reflog expire"
  "git gc[[:space:]]+.*--prune"
  # rebase --onto による履歴付け替え（force push 不要で履歴破壊）
  "git rebase[[:space:]]+.*--onto"
  # filter-branch / filter-repo による履歴丸ごと書き換え
  "git filter-branch"
  "git filter-repo"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0
