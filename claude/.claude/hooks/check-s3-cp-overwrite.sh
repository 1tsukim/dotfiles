#!/bin/bash
# PreToolUse(Bash) hook: aws s3 cp で既存 S3 key を上書きする事故を事前ブロック
# 方針:
#   - ローカル → S3 cp (アップロード) のみチェック対象
#   - S3 → ローカル (ダウンロード) はチェックなし (ローカル上書きはユーザー手元の問題)
#   - S3 → S3 cp は完全ブロック (別バケット書き込みリスク)
#   - 単一 cp: aws s3api head-object で精密判定 (前方一致誤検知を回避)
#   - --recursive: ローカル全ファイル列挙 + S3 prefix 配下を aws s3 ls --recursive で列挙、突合
#   - --include / --exclude は無視 (過剰判定だが安全側)
#   - 隠しファイル/ディレクトリ (.git/, .DS_Store, __pycache__, .venv 等) はローカル列挙から除外
#   - profile: コマンドの --profile X を尊重、無ければ ${AWS_PROFILE_ADMIN}
#   - aws CLI 失敗時は fail-safe (block)
#   - タイムアウト 10 秒

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# aws s3 cp を含まなければ対象外
if ! echo "$COMMAND" | grep -qE '(^|[^a-zA-Z0-9_-])aws(admin)?[[:space:]]+s3[[:space:]]+cp([[:space:]]|$)'; then
  exit 0
fi

# aws s3 cp の後ろの引数列を抽出
# 簡易パース: クォート内のスペースは正確に扱えない (実用上は問題なし、誤検知側に倒れる)
ARGS_PART=$(echo "$COMMAND" | sed -nE 's/^.*[[:space:]]?(command[[:space:]]+)?aws(admin)?[[:space:]]+s3[[:space:]]+cp[[:space:]]+(.*)$/\3/p')

if [ -z "$ARGS_PART" ]; then
  exit 0
fi

# 引数を配列にパース
read -r -a ARGS <<< "$ARGS_PART"

# オプション / 位置引数の分離
RECURSIVE=0
PROFILE=""
POSITIONAL=()

# 値を取るフラグ一覧 (これらの次の引数は値として消費)
VALUE_FLAGS_RE='^(--profile|--include|--exclude|--metadata-directive|--storage-class|--acl|--cache-control|--content-encoding|--content-type|--content-language|--content-disposition|--expires|--grants|--website-redirect|--sse|--sse-c|--sse-c-key|--sse-c-copy-source|--sse-c-copy-source-key|--sse-kms-key-id|--source-region|--region|--endpoint-url|--checksum-algorithm|--copy-props|--checksum-mode|--page-size|--metadata|--tagging|--output)$'

i=0
n=${#ARGS[@]}
while [ $i -lt $n ]; do
  arg="${ARGS[$i]}"
  case "$arg" in
    --recursive)
      RECURSIVE=1
      ;;
    --profile=*)
      PROFILE="${arg#--profile=}"
      ;;
    *)
      if [[ "$arg" =~ $VALUE_FLAGS_RE ]]; then
        # 次の引数を値として消費
        if [ "$arg" = "--profile" ]; then
          i=$((i + 1))
          PROFILE="${ARGS[$i]}"
        else
          i=$((i + 1))
        fi
      elif [[ "$arg" == --* ]]; then
        # 単独フラグ
        :
      else
        POSITIONAL+=("$arg")
      fi
      ;;
  esac
  i=$((i + 1))
done

# 位置引数が 2 つ揃わなければ aws CLI 側でエラー、通す
if [ ${#POSITIONAL[@]} -lt 2 ]; then
  exit 0
fi

SOURCE="${POSITIONAL[0]}"
DEST="${POSITIONAL[-1]}"

# 方向判定
is_s3() { [[ "$1" == s3://* ]]; }

# S3 → S3: 完全ブロック
if is_s3 "$SOURCE" && is_s3 "$DEST"; then
  echo "BLOCKED: '$COMMAND' is an S3-to-S3 copy (s3://... → s3://...). The user has disallowed this route. Download first, then upload manually if intentional." >&2
  exit 2
fi

# S3 → ローカル (ダウンロード): 対象外
if is_s3 "$SOURCE" && ! is_s3 "$DEST"; then
  exit 0
fi

# ローカル → ローカル: aws CLI 側でエラー、通す
if ! is_s3 "$SOURCE" && ! is_s3 "$DEST"; then
  exit 0
fi

# ここから ローカル → S3 アップロード
LOCAL_SRC="$SOURCE"
S3_DEST="$DEST"

# profile のデフォルト
if [ -z "$PROFILE" ]; then
  PROFILE="${AWS_PROFILE_ADMIN}"
fi

# 隠しファイル/ディレクトリ除外パターン
HIDDEN_RE='(^|/)(\.git|\.DS_Store|__pycache__|\.venv|node_modules|\.ipynb_checkpoints|\.pytest_cache|\.mypy_cache|\.ruff_cache|\.next|dist|build)(/|$)'

if [ "$RECURSIVE" -eq 1 ]; then
  # --recursive: ディレクトリ突合モード
  if [ ! -d "$LOCAL_SRC" ]; then
    # source がディレクトリでない場合は aws CLI 側でエラーになる、通す
    exit 0
  fi

  # ローカル側のファイルリスト (相対パス、隠しファイル除外)
  LOCAL_FILES=$(cd "$LOCAL_SRC" 2>/dev/null && find . -type f 2>/dev/null | sed 's|^\./||' | grep -vE "$HIDDEN_RE" | sort)

  if [ -z "$LOCAL_FILES" ]; then
    # アップロード対象なし
    exit 0
  fi

  # S3 prefix 末尾スラッシュを保証
  S3_PREFIX="$S3_DEST"
  [[ "$S3_PREFIX" != */ ]] && S3_PREFIX="${S3_PREFIX}/"

  # S3 側を列挙 (タイムアウト 10 秒)
  S3_OUTPUT=$(timeout 10 aws s3 ls "$S3_PREFIX" --recursive --profile "$PROFILE" 2>&1)
  LS_EXIT=$?

  if [ $LS_EXIT -ne 0 ]; then
    # ls 失敗: fail-safe
    # 出力が空かつ exit 1 は「prefix 配下にオブジェクトなし」(aws CLI の挙動) の可能性
    if [ $LS_EXIT -eq 1 ] && [ -z "$S3_OUTPUT" ]; then
      exit 0
    fi
    {
      echo "BLOCKED: 'aws s3 ls $S3_PREFIX --recursive' failed (exit=$LS_EXIT). Cannot verify overwrite safety."
      echo "Output: $S3_OUTPUT"
      echo "Fix the credentials/network/profile issue, or run the cp manually if you're sure no overwrite happens."
    } >&2
    exit 2
  fi

  # S3 出力から key を抽出して prefix 相対パスに変換
  # 形式: "2026-01-01 12:00:00     1234 prefix/path/to/file.ext"
  S3_PREFIX_PATH=$(echo "$S3_PREFIX" | sed -E 's|^s3://[^/]+/||')
  S3_FILES=$(echo "$S3_OUTPUT" \
    | awk 'NF>=4 {key=""; for(i=4;i<=NF;i++) key=key (i==4 ? "" : " ") $i; print key}' \
    | sed "s|^${S3_PREFIX_PATH}||" \
    | grep -v '^$' \
    | sort)

  # 突合
  DUPS=$(comm -12 <(echo "$LOCAL_FILES") <(echo "$S3_FILES"))

  if [ -n "$DUPS" ]; then
    COUNT=$(echo "$DUPS" | wc -l | tr -d ' ')
    FIRST_10=$(echo "$DUPS" | head -10)
    {
      echo "BLOCKED: Recursive cp would overwrite $COUNT existing object(s) under $S3_PREFIX:"
      echo "$FIRST_10" | sed 's|^|  - |'
      if [ "$COUNT" -gt 10 ]; then
        echo "  ... and $((COUNT - 10)) more"
      fi
      echo "Have the user run 'aws s3 ls $S3_PREFIX --recursive' to inspect, then upload manually with non-conflicting keys."
    } >&2
    exit 2
  fi

  # 重複なし: 通す
  exit 0
else
  # 単一 cp モード
  # dest が prefix (末尾 /) の場合は source の basename を補う
  if [[ "$S3_DEST" == */ ]]; then
    BASE=$(basename "$LOCAL_SRC")
    S3_FULL="${S3_DEST}${BASE}"
  else
    S3_FULL="$S3_DEST"
  fi

  # bucket / key の分離
  S3_PATH="${S3_FULL#s3://}"
  BUCKET="${S3_PATH%%/*}"
  KEY="${S3_PATH#*/}"

  if [ "$BUCKET" = "$KEY" ] || [ -z "$KEY" ]; then
    # s3://bucket だけ (key 無し) → aws CLI 側でエラー、通す
    exit 0
  fi

  # head-object で精密判定 (タイムアウト 10 秒)
  HEAD_OUTPUT=$(timeout 10 aws s3api head-object --bucket "$BUCKET" --key "$KEY" --profile "$PROFILE" 2>&1)
  HEAD_EXIT=$?

  case $HEAD_EXIT in
    0)
      # 存在: ブロック
      echo "BLOCKED: s3://$BUCKET/$KEY already exists. Uploading would overwrite the existing object. Have the user execute manually if intentional." >&2
      exit 2
      ;;
    254|255)
      # 不存在 (Not Found): OK 通す
      exit 0
      ;;
    *)
      # その他のエラー (権限・ネットワーク・タイムアウト): fail-safe
      {
        echo "BLOCKED: 'aws s3api head-object --bucket $BUCKET --key $KEY --profile $PROFILE' failed (exit=$HEAD_EXIT). Cannot verify overwrite safety."
        echo "Output: $HEAD_OUTPUT"
      } >&2
      exit 2
      ;;
  esac
fi
