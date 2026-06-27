---
paths:
  - "**/*.py"
  - "**/*.ipynb"
---

# ruff check --fix のある repo での import 追加順序

PostToolUse hook で `ruff format && ruff check --fix` が走るリポジトリでは、
**「先に import を追加 → 後で使用箇所を書く」順だと、import 追加直後の
hook 起動時点で F401 (unused-import) と判定されて削除される**。

## 回避策

以下のいずれか：

1. **使用箇所を先に書いてから import を追加する**
   - 1 Edit 目: 関数呼び出しなど使用箇所だけ追加 (NameError 一時的に発生する状態)
   - 2 Edit 目: import を追加 → hook 起動時に「使われている」と判定され残る

2. **1 Edit で import と最初の使用箇所を同時に書く**
   - 大きな old_string → new_string にして、両方含める

3. **F401 の auto-fix を一時的に抑止**
   - `# noqa: F401` を付ける（恒久的な解にはならない）

## 検出

新規モジュールを使うコードを書いたあと、`rg -n "from <module>" <file>` で
import 行の存在を確認するか、syntax check ではなく実際に Streamlit / FastAPI を
起動して NameError を確認する。`ast.parse` の syntax check では型注釈の
NameError（`Foo | None` で `Foo` 未定義など）は検出できない。

## 失敗履歴

- mitococa-tools repo (2026-05-26): `eval_project_picker` と `s3_image_loader`
  の import が 2 度連続で hook により削除され、いずれも Streamlit 起動時の
  NameError として表面化。
