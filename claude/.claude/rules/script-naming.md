---
paths:
  - "**/*.sh"
  - "**/*.py"
---

# スクリプトの命名（hook 摩擦回避）

自作スクリプト・ファイル名で `delete-` `terminate-` `purge-` `release-` `revoke-` `deregister-` `disassociate-` `detach-` などのハイフン続きを避ける。これらは `~/.claude/hooks/block-dangerous-aws.sh` の破壊的サブコマンド名パターンに引っかかり、`bash delete-old.sh` 等の実行がブロックされる。

- ❌ `delete-old.sh` / `terminate-job.sh` / `purge-cache.sh`
- ✅ `cleanup_old.sh` / `stop_job.sh` / `clear_cache.sh`（アンダースコア区切り、または別動詞）

`delete.sh` / `delete_old.sh` / `my-delete.sh` のように **`delete` の直後がハイフン以外** なら通る。回避が難しい既存ファイルがある場合は `mv ~/.claude/hooks/block-dangerous-aws.sh{,.off}` で hook を一時退避してから作業する手があるが、**この操作はユーザーが手動で行う**（`claude-config-safety.md` 参照）。
