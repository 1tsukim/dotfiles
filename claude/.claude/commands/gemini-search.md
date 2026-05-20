---
description: web 検索が必要なときは builtin WebSearch ではなく `gemini --prompt 'WebSearch: <query>'` を使う。
---

## Gemini Search

### 呼び出し

```bash
perl -e 'alarm shift; exec @ARGV' 90 gemini --prompt 'WebSearch: <query>' > /tmp/gemini-$$.out 2>&1
```

Bash ツールは `run_in_background: true` で投げ、完了 notification 後に `/tmp/gemini-$$.out` を `Read`。

### 禁止

- `gemini` の出力を `head` / `tail` / `sort` / `grep` にパイプしない（EOF 待ちでハングか判別不能になる）
- `perl -e 'alarm ...'`（または `gtimeout`）なしで呼ばない（grounding 失敗時に 60 分超生存しうる）

### ハング時

```bash
pkill -f 'gemini --prompt' || true
```
