---
paths:
  - "**/*.sh"
  - "**/*.py"
  - "**/*.ipynb"
  - "**/aws/**/*"
  - "**/.aws/**/*"
  - "**/s3/**/*"
---

# AWS CLI (S3)

S3 操作は `~/.local/bin/` のラッパーを使う：

- `s3-ls [s3://bucket/prefix/]` : 一覧（profile `$AWS_PROFILE_ADMIN` 自動付与、env var は local.zsh で export）
- `s3-safe-cp <local-file> <s3://bucket/key>` : アップロード（同名 key 存在確認 → 無ければ実行、あれば中止）

直接 `aws s3` を叩くのはラッパーで対応できないケース（`sync`, `cp --recursive`, S3→ローカルのダウンロード等）のみ。その場合も `--profile "$AWS_PROFILE_ADMIN"` を必ず付ける。

`s3-safe-cp` が「既に存在」で中止したら、上書きが本当に必要かユーザーに確認する。OK が出たら明示的に `aws s3 cp` を直接実行する。
