#!/bin/bash
# AWS CLI ホワイトリストフック
# 方針: ユーザーが使うのは S3 のアップロード/ダウンロード/一覧確認のみ。
# 許可:
#   - aws s3 cp   (アップロード/ダウンロード)
#   - aws s3 ls   (一覧表示のみ)
#   - aws --version / --help
#   - aws configure list-* (list-profiles など)
#   - aws ... help (任意階層のヘルプ参照)
#   - man / which / type / whereis / whatis aws (ドキュメント参照)
# 上記以外の aws コマンドはすべてブロック (EC2 全操作、IAM/RDS/Lambda 系、
# aws s3 sync/rm/rb/mb/mv/presign を含む)
# sync は --delete で同期先削除になり得るため許可リストから除外 (2026-05-13)
#
# 検出対象の呼び出し形式: aws / awsadmin / command aws / フルパス末尾 /aws
# 単語境界はシェルメタ文字 (クォート/括弧/=/;/|/& 等) も非識別子として扱う。
# これにより 'aws' / "aws" / (aws / $(aws / =aws / \aws のすり抜けを捕捉。
# チェイン (;, &&, ||, |, &) の各セグメントを個別に評価。
# 間接実行 (eval / bash -c / sh -c / base64 -d | sh) で aws を引数に取る形もブロック。
#
# 限界: コマンド文字列に aws リテラルがまったく出現しないルート
# (例: A=aws; $A ec2 ... の後段、boto3 等 SDK 直叩き) は原理的に検知不能。
# その場合は IAM Deny ポリシー側で対策する必要がある。

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# シェル単語境界 (識別子文字以外を境界扱い)
LB='(^|[^a-zA-Z0-9_-])'
RB='($|[^a-zA-Z0-9_-])'

# AWS の破壊的サブコマンド名そのもの (aws リテラルが見えない経路でも発火)
# 例: $(which aws) ec2 terminate-instances / フルパス /usr/local/bin/aws / awsadmin
# 誤検知 (説明文や delete- を含むファイル名等) は許容。漏洩防止優先。
DANGEROUS_SUBCOMMANDS=(
  # EC2 / Beanstalk / EMR / Batch / ASG の即破壊
  "${LB}terminate-(instances?|environment|clusters?|job|instance-in-auto-scaling-group)${RB}"
  # delete-* 全般 (delete-object/bucket/role/user/snapshot/volume/...)
  "${LB}delete-[a-z][a-z-]*"
  # ネットワーク・ストレージのデタッチ系
  "${LB}detach-(volume|policy|user-policy|role-policy|group-policy|internet-gateway|network-interface|vpn-gateway)${RB}"
  # IAM 関連の解除
  "${LB}disassociate-[a-z][a-z-]*"
  # SG ルール削除
  "${LB}revoke-security-group-(ingress|egress)${RB}"
  # EIP / Host 解放
  "${LB}release-(address|hosts)${RB}"
  # S3 マルチパート中断
  "${LB}abort-multipart-upload${RB}"
  # SQS キュー全削除
  "${LB}purge-queue${RB}"
  # 各種 deregister (ECS task-definition, ELB targets 等)
  "${LB}deregister-[a-z][a-z-]*"
  # SageMaker / RDS / Glue / StepFunctions の中断
  "${LB}stop-(training-job|processing-job|transform-job|hyper-parameter-tuning-job|notebook-instance|db-instance|execution|crawler|job-run|backup-job)${RB}"
  # CloudFormation キャンセル系
  "${LB}cancel-update-stack${RB}"
  # S3 書き換え/削除サブコマンド (aws を省略しても "s3 rm" 等で発火、sync は変数経由保険)
  "${LB}s3[[:space:]]+(rm|rb|mb|mv|presign|sync)${RB}"
  # --- Phase 2 拡張: 業務外動詞を L0 に追加 (変数経由バイパスの最後の砦) ---
  # IAM 権限拡大 (権限の永続化・最高権限化の防止)
  "${LB}attach-(role|user|group)-policy${RB}"
  "${LB}add-(user-to-group|role-to-instance-profile|permission)${RB}"
  "${LB}(update|set)-(assume-role-policy|default-policy-version|login-profile)${RB}"
  # IAM 認証情報の新規生成
  "${LB}create-(user|role|group|policy|policy-version|access-key|login-profile|service-linked-role)${RB}"
  "${LB}(get-session-token|assume-role(-with-(saml|web-identity))?)${RB}"
  # 既存リソース上書き / 設定改変 (put-* / modify-* / update-*)
  "${LB}put-(object|bucket-[a-z-]+|public-access-block|user-policy|role-policy|group-policy|item|function-concurrency|metric-alarm|retention-policy)${RB}"
  "${LB}modify-[a-z][a-z-]*${RB}"
  "${LB}update-(function-code|function-configuration|stack|endpoint|table|db-instance|distribution|domain)${RB}"
  # リソース新規起動 (コスト発生 / 既存環境への影響)
  "${LB}run-instances${RB}"
  "${LB}start-(instances|training-job|processing-job|transform-job|build|execution|crawler|notebook-instance|db-instance|hyper-parameter-tuning-job)${RB}"
  "${LB}create-(snapshot|image|stack|change-set|bucket|function|db-instance|cluster|endpoint|training-job|table)${RB}"
  # 再起動・リセット・復元
  "${LB}reboot-(instances|db-instance|cache-cluster)${RB}"
  "${LB}reset-(network-interface-attribute|snapshot-attribute|image-attribute|db-cluster-parameter-group)${RB}"
  "${LB}restore-(db-instance-from-snapshot|db-cluster-from-snapshot|table-to-point-in-time|object|table-from-backup)${RB}"
  # ネットワーク改変
  "${LB}replace-(network-acl-entry|route|iam-instance-profile-association)${RB}"
  "${LB}change-resource-record-sets${RB}"
  # 登録・インポート・コピー
  "${LB}register-(image|task-definition|targets|instances-with-load-balancer)${RB}"
  "${LB}import-(key-pair|image|snapshot)${RB}"
  "${LB}copy-(object|snapshot|image)${RB}"
  # KMS 鍵の停止 / 削除予約 (復号不能化)
  "${LB}(disable|schedule)-key(-rotation|-deletion)?${RB}"
)

for pattern in "${DANGEROUS_SUBCOMMANDS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' contains an AWS destructive subcommand pattern matching '$pattern'. This blocks even via \$(which aws), full path /aws, or other indirect routes." >&2
    exit 2
  fi
done

# 間接実行 + aws を引数に取るパターン (eval/bash -c/sh -c/base64-decoded-piped-shell)
# クォート内に aws リテラルがある場合をリテラルマッチで捕捉する。
# base64 はデコード後の中身を見られないが、`| bash` 等パイプ先がシェルなら危険として一律拒否。
INDIRECT_AWS_PATTERNS=(
  # eval "aws ..." / eval 'aws ...' / eval $(aws ...) など、eval の後に aws が現れる
  "(^|[^a-zA-Z0-9_-])eval[[:space:]]+[^|;&]*aws"
  # bash/sh/zsh/ksh -c "aws ..."
  "(^|[^a-zA-Z0-9_-])(bash|sh|zsh|ksh)[[:space:]]+-c[[:space:]]+[^|;&]*aws"
  # base64 -d ... | bash / sh / zsh (aws リテラルが base64 化されたうえでシェルに渡る)
  "base64[[:space:]]+(-d|--decode).*\\|[[:space:]]*(bash|sh|zsh|ksh)([[:space:]]|$)"
)

for pattern in "${INDIRECT_AWS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' uses indirect execution (eval / bash -c / sh -c / base64 -d | sh) referencing aws. The user has disallowed indirect aws invocation." >&2
    exit 2
  fi
done

# aws の呼び出しを示す正規表現
AWS_INVOKE_RE="${LB}(command[[:space:]]+)?aws(admin)?${RB}|${LB}[^[:space:]]*/aws${RB}"

# 許可パターン (aws / awsadmin / command aws / フルパスの /aws を網羅)
ALLOWED_PATTERNS=(
  # aws s3 cp / ls (sync は除外)
  "${LB}(command[[:space:]]+)?aws(admin)?[[:space:]]+s3[[:space:]]+(cp|ls)${RB}"
  "${LB}[^[:space:]]*/aws[[:space:]]+s3[[:space:]]+(cp|ls)${RB}"
  # aws --version / aws --help
  "${LB}(command[[:space:]]+)?aws(admin)?[[:space:]]+--(version|help)${RB}"
  "${LB}[^[:space:]]*/aws[[:space:]]+--(version|help)${RB}"
  # aws configure list-*
  "${LB}(command[[:space:]]+)?aws(admin)?[[:space:]]+configure[[:space:]]+list[a-z-]*${RB}"
  "${LB}[^[:space:]]*/aws[[:space:]]+configure[[:space:]]+list[a-z-]*${RB}"
  # ドキュメント参照: man / which / type / whereis / whatis + aws
  "${LB}(man|which|type|whereis|whatis)[[:space:]]+aws${RB}"
  # aws ... help (aws help / aws s3 help / aws ec2 describe-instances help 等)
  "${LB}(command[[:space:]]+)?aws(admin)?[[:space:]]+([a-z0-9_-]+[[:space:]]+)*help${RB}"
  "${LB}[^[:space:]]*/aws[[:space:]]+([a-z0-9_-]+[[:space:]]+)*help${RB}"
)

# コマンドをシェル区切り (;, &&, ||, |, &) で分割し、各セグメントを評価
# クォートやサブシェル $(...) は厳密にはパースしないが、Claude が打つ典型的な
# 一行コマンドではこれで十分。回避コマンドが現れたら正規表現を強化する。
SEGMENTS=$(echo "$COMMAND" | sed -E 's/(\|\||&&|;|\||&)/\n/g')

while IFS= read -r seg; do
  # aws を呼んでいないセグメントは無視
  if ! echo "$seg" | grep -qE "$AWS_INVOKE_RE"; then
    continue
  fi

  # cp に --delete が含まれる場合は破壊的なのでブロック (通常 cp に --delete は無いが念のため)
  # sync は ALLOWED_PATTERNS から外れているので別途検知不要 (許可リスト不一致でブロックされる)
  if echo "$seg" | grep -qE 'aws(admin)?[[:space:]]+.*s3[[:space:]]+cp([[:space:]]|$)' \
     && echo "$seg" | grep -qE '([[:space:]]|^)--delete([[:space:]]|=|$)'; then
    echo "BLOCKED: '$seg' contains '--delete'. This deletes files on the destination side. The user has disallowed any deletion via AWS CLI." >&2
    exit 2
  fi

  # --- Phase 1: aws s3 cp 固有の事故防止 ---
  # cp は許可されているが、以下のオプション/引数組み合わせは実害を生む。
  if echo "$seg" | grep -qE 'aws(admin)?[[:space:]]+.*s3[[:space:]]+cp([[:space:]]|$)'; then
    # /dev/null や /dev/zero を S3 に書き込む = 既存 key を空で上書き (事実上の削除)
    if echo "$seg" | grep -qE '[[:space:]]+/dev/(null|zero|random|urandom)[[:space:]]+s3://'; then
      echo "BLOCKED: '$seg' copies /dev/null|zero|random to S3, effectively erasing the destination key." >&2
      exit 2
    fi
    # S3 から - (stdout) に出力 = 機密内容を画面に流す情報漏洩経路
    if echo "$seg" | grep -qE 's3://[^[:space:]]+[[:space:]]+-([[:space:]]|$)'; then
      echo "BLOCKED: '$seg' streams an S3 object to stdout (dest='-'). This is a data exfiltration route." >&2
      exit 2
    fi
    # 公開化 ACL (public-read / public-read-write / authenticated-read)
    if echo "$seg" | grep -qE '([[:space:]]|^)--acl[[:space:]]+(public-|authenticated-)'; then
      echo "BLOCKED: '$seg' sets a public/authenticated ACL. Public-disclosure risk." >&2
      exit 2
    fi
    # メタデータ書き換え (REPLACE は既存属性をクリア)
    if echo "$seg" | grep -qE '([[:space:]]|^)--metadata-directive[[:space:]]+REPLACE'; then
      echo "BLOCKED: '$seg' replaces object metadata. The user has disallowed metadata rewriting." >&2
      exit 2
    fi
    # オブジェクトレベルの権限付与
    if echo "$seg" | grep -qE '([[:space:]]|^)--grants([[:space:]]|=)'; then
      echo "BLOCKED: '$seg' grants object-level permissions. The user has disallowed permission changes." >&2
      exit 2
    fi
  fi

  allowed=0
  for pattern in "${ALLOWED_PATTERNS[@]}"; do
    if echo "$seg" | grep -qE "$pattern"; then
      allowed=1
      break
    fi
  done

  if [ $allowed -eq 0 ]; then
    echo "BLOCKED: '$seg' is not in the AWS CLI allowlist. Permitted: aws s3 (cp|ls), aws --version, aws --help, aws configure list-*, man/which/type/whereis aws, aws ... help. Everything else (EC2/IAM/RDS/Lambda, aws s3 sync/rm/rb/mb/mv/presign) is blocked." >&2
    exit 2
  fi
done <<< "$SEGMENTS"

exit 0
