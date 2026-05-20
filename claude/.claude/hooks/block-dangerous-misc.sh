#!/bin/bash
# PreToolUse(Bash) hook: git 以外の破壊的コマンドをブロック
# block-dangerous-git.sh と block-dangerous-aws.sh の補完
# 対象: rm -rf 系の危険ターゲット、破壊的 SQL 操作

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

DANGEROUS_PATTERNS=(
  # rm -rf with dangerous targets (/, ~, $HOME)
  'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+(/[[:space:]]|/$|~|\$HOME|"\$HOME")'
  # rm -rf /*  ~/*
  'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+(/|~)\*'
  # rm -rf 相対パス (. / .. / ./xxx / ../yyy) — カレントや親ディレクトリの全削除
  'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+(\.|\.\.)([[:space:]/]|$)'
  # find ... -delete (rm を使わずファイル削除)
  'find[[:space:]].*[[:space:]]-delete([[:space:]]|$)'
  # 破壊的 SQL (DROP TABLE/DATABASE, TRUNCATE TABLE) — クォート/括弧/セミコロンも境界扱い
  '(^|[^a-zA-Z0-9_])drop[[:space:]]+(table|database)([^a-zA-Z0-9_]|$)'
  '(^|[^a-zA-Z0-9_])truncate[[:space:]]+table([^a-zA-Z0-9_]|$)'
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0
