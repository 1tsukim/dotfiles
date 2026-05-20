#!/bin/bash
# PreToolUse(Bash) hook: 機密ファイルに触れる Bash コマンドをブロック
# コマンド名（cat/less/head/...）で分類せず、コマンド文字列に機密パスが
# 出現したらブロックする単純マッチング。誤検知より漏洩防止を優先。
# 正規の操作で止まった場合は 'command <cmd> ...' でバイパス可能。

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# 機密パスのパターン（基本はファイルパス断片で検出）
# - ~/.aws/credentials, ~/.aws/config, $HOME/.aws/... も含む
# - ~/.ssh/id_rsa, id_ed25519, id_ecdsa, id_dsa
# - credentials.json (GCP/Firebase)
# - .env / .env.* （プロジェクト直下の環境変数ファイル）
# - *.pem / *.p12 （鍵・証明書）
PATTERN='(\.aws/(credentials|config)|\.ssh/id_(rsa|ed25519|ecdsa|dsa)|credentials\.json|(^|/|[[:space:]]|=)\.env([[:space:]]|$|\.)|\.pem([[:space:]]|$|"|'"'"')|\.p12([[:space:]]|$|"|'"'"'))'

if echo "$COMMAND" | grep -qE "$PATTERN"; then
  echo "BLOCKED: '$COMMAND' touches a sensitive path. The user has prevented you from reading/copying credentials, ssh keys, or .env. Bypass for legitimate use: 'command <cmd> ...' or ask the user first." >&2
  exit 2
fi

exit 0
