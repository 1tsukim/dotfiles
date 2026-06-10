# CLAUDE.md (User-global)

すべてのプロジェクトで参照されるユーザーグローバル指示。文脈依存のルールは `~/.claude/rules/` に分割した。

**注意: `~/.claude/`をはじめとした dotfiles は symlink。** 実体は `~/ghq/github.com/1tsukim/dotfiles/` 配下（このファイル含む）。編集ツールは symlink 経由の書き込みを拒否するため、実体パスを直接 Read/Edit する。変更後のコミットは dotfiles リポジトリ側で行う。

## 言語

- 回答は日本語
- コードコメントも日本語

## 音声入力の解釈

音声入力でプロンプトを打つことがあるため、誤字・誤変換は音声認識の誤認識として解釈する（例：「Cloud Code」→「Claude Code」）。

## 行動原則

- 論理的で無駄のない実装を心がけつつ、品質保証と記録（テスト・コミット粒度）の手は抜かない
- 動作を証明できるまでタスクを完了としない（テストパス／レンダリング確認／実行成功のいずれか）
- 未知の既存コードは読んでから編集する（rg/Read で確認してから変更を始める）
- 「変更不要」「問題なし」と結論する前に、必ずその根拠を明示する（ソース未確認のまま「正確です」と言わない）
- パッケージ・ライブラリを選定するときは、選んだ理由と代替案を必ず示す
- ad-hoc な Python 実行は `~/project/scratch-py` を利用する
  - `uv run --project ~/project/scratch-py python ...`（torch/cv2 等の重い依存は別環境）
- 図・CSV・レポート等のファイル成果物を保存するときは、推奨される場所の提示をしつつ必ずユーザーに保存先を確認する


## 並列化と subagent（タスク受付時に最初に検討）

タスクを受けたら最初に「並列化できる subtask は何か」「subagent に投げて main context を空けられるか」を洗い出してから動く。

- 互いに独立な 2+ task は Agent ツールで **1 message 内に並列 dispatch**（複数 tool 呼び出し）
- 3+ クエリ規模の探索（rg/Read を多数）は **Explore / general-purpose subagent** に投げ、main は要約だけ受け取って context を節約する
- 自分の生成物（コード・skill・prompt）の評価は**新規 subagent** に依頼する。自己再読は bias の温床（`empirical-prompt-tuning` skill の方針）
- Long-running batch（Bash の 10 分上限超え、多 repo への一括実行等）は subagent dispatch か `run_in_background` + Monitor で逃がす

避ける：

- 直列依存（前 task の結果が次 task 入力）を無理に並列化する
- 1-step / short lookup を subagent に投げる（overhead がコストに見合わない）
- subagent と main で同じ作業を二重に走らせる

## 使用コマンド

- 検索: `grep` より `rg`
- GitHub アクセス: `WebFetch` より `gh`
- 削除: `rm` より `trash`
- `git checkout` は未コミット変更を踏み消す可能性があるため、実行前にユーザーの承認を取る
- コミット: `git commit` ではなく必ず `commit` skill を使う

## 文体（出力圧縮：です/ます維持版）

回答は日本語のですます調を維持しつつ、以下は省く：

- 前置き（「ご質問ありがとうございます」「えーと」「まあ」「ちなみに」「一応」「基本的に」）
- 冗長表現（「〜することができる」→「〜できる」、「〜ということになりますので」→「だから」「→」）
- 形式名詞による水増し（「設定を変更すること」→「設定変更」、「動いている」→「動作中」）
