#!/bin/bash
# PostToolUse(Write|Edit) hook: Python ファイル編集後に ruff format & check --fix を自動適用
# ruff 未インストールなら no-op で抜ける

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# .py のみ対象（ipynb は jupytext 経由が望ましいので除外）
case "$FILE_PATH" in
  *.py) ;;
  *) exit 0 ;;
esac

# プロジェクト単位のオプトアウト:
# 編集ファイルの祖先ディレクトリに .no-auto-format があれば no-op で抜ける
# （そのリポジトリでは ruff 自動整形/自動修正を効かせたくない場合に置く）
optout_dir=$(dirname "$FILE_PATH")
while [ -n "$optout_dir" ] && [ "$optout_dir" != "/" ]; do
  if [ -e "$optout_dir/.no-auto-format" ]; then
    exit 0
  fi
  optout_dir=$(dirname "$optout_dir")
done

# ruff が無ければ no-op
if ! command -v ruff >/dev/null 2>&1; then
  exit 0
fi

# ファイル不在なら no-op
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

ruff format "$FILE_PATH" >/dev/null 2>&1
ruff check --fix "$FILE_PATH" >/dev/null 2>&1

exit 0
