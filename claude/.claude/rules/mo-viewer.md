---
paths:
  - "**/*.md"
---

# Markdown ビューア: `mo`

ブラウザでライブリロード付きで Markdown を見るツール（`/opt/homebrew/bin/mo`）。詳細は `mo --help`。

単独セッションで開きたいときは `mo-reset <file.md>` を使う（shutdown + clear + open を一発で）。

`mo` 直叩きの落とし穴：ポート 6275 で 1 台のサーバーを共有しているため、既存セッションに追記される。複数ファイルをまとめて見るならそれで OK だが、単独表示にしたいときは必ず `mo-reset` 経由。
