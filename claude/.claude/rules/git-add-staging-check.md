# git add 後の staged 確認（venv 風 gitignore の巻き込み対策）

`.gitignore` に venv テンプレ由来の `lib/`（先頭スラッシュ無し）があると、
**ルート以外の `src/.../lib/` など任意階層の `lib/` も巻き込む**。
`git add <dir>` はディレクトリ指定だと ignore 対象を**警告なくスキップ**するため、
vendored な核がコミットされず silently 取りこぼす。

## 確認

`git add <dir>` の後、source ツリー内に venv 風名（`lib/` `bin/` `build/` `include/`）の
ディレクトリがある、または vendored ディレクトリを新規 add したときは、
`git status` / `git show --stat`（commit 後）で意図したファイルが staged されたか確認する。

取りこぼしの兆候：`git check-ignore -v src/.../lib/foo.py` がヒットする、
`git status --ignored` に source 配下のファイルが出る。

## 根本対処

巻き込みを止める。いずれか：

- gitignore をルートにアンカー：`lib/` → `/lib/`（または `venv/lib/`）
- negation で除外解除：`!src/streamlit_app/lib/`

## 失敗履歴

- Streamlit アプリ（2026-05）: `.gitignore` の venv 由来 `lib/` が
  `src/streamlit_app/lib/` を巻き込み、vendored 核が staged されずコミット漏れ。
