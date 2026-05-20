# dotfiles

![macOS](https://img.shields.io/badge/macOS-000?logo=apple&logoColor=white)
![Zsh](https://img.shields.io/badge/Zsh-1a1a1a?logo=gnubash&logoColor=F15A24)
![Homebrew](https://img.shields.io/badge/Homebrew-FBB040?logo=homebrew&logoColor=black)
![GNU Stow](https://img.shields.io/badge/GNU%20Stow-A42E2B?logo=gnu&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-D97757?logo=anthropic&logoColor=white)
![Cursor](https://img.shields.io/badge/Cursor-000?logo=cursor&logoColor=white)

XDG Base Directory 準拠の dotfiles。GNU Stow で `$HOME` に symlink 展開する。

## 構成

| パッケージ | 内容 |
|---|---|
| `zsh/` | zsh 本体設定 (`.zshenv` + `ZDOTDIR=~/.config/zsh` 配下一式) |
| `git/` | git config と global ignore |
| `tmux/` | tmux.conf と status バーヘルパー |
| `tealdeer/` | tldr クライアント (キャッシュ場所だけ XDG_CACHE_HOME に向ける) |
| `karabiner/` | Karabiner-Elements のカスタムキーマップ (`karabiner.json` のみ。`automatic_backups/` `assets/` は含めない) |
| `claude/` | Claude Code 設定 (`CLAUDE.md`, `settings.json`, `hooks/`, `agents/`, `commands/`, `rules/`, `statusline-command.sh`)。`skills/` と `projects/.../memory/` は別 private repo で管理 (下記)。runtime state (session, history, cache, telemetry, todos, file-history, paste-cache, .statusline-sessions-*, .DS_Store, .last-cleanup, settings.local.json) は除外 |
| `codex/` | OpenAI Codex CLI 設定 (`config.toml` のみ。`auth.json` `cache/` `log/` `sessions/` `*.sqlite*` 等の runtime state は除外) |
| `cmux/` | cmux ターミナル設定 (`~/.config/cmux/cmux.json` + `settings.json`)。`~/.cmuxterm/` の workstream/session ログや `~/Library/Application Support/cmux/` の socket・session は除外 |
| `cursor/` | Cursor の User snippets (`python.json` 17個)。配置先は `~/Library/Application Support/Cursor/User/snippets/` |

リポ直下の `Brewfile` は Stow せずそのまま読む。`.zshrc` で `HOMEBREW_BUNDLE_FILE` をこのファイルに固定しているため、普段の `brew bundle dump` もここに書き出される。

### Claude Code memory / skills について

`~/.claude/projects/-Users-*/memory/` (memory) と `~/.claude/skills/` (skills) は **別の private repo（個人用）** で管理しているため、本リポには含まれません。

- `.gitignore` で `claude/.claude/projects/` と `claude/.claude/skills/` を除外
- `setup.sh` は対応する companion private repo を optional に clone + stow を試行します
  - 権限がなければ自動で skip（fork 者でも dotfiles 単体で動作）

fork した方は `~/.claude/projects/-Users-<username>/memory/` と `~/.claude/skills/` を直接管理するか、自分用の companion private repo を作成して `setup.sh` の該当箇所を書き換えてください。


## セットアップ (新マシン)

```bash
# 1. リポを取得
ghq get 1tsukim/dotfiles   # ghq があれば
# git clone https://github.com/1tsukim/dotfiles ~/ghq/github.com/1tsukim/dotfiles   # なければ

# 2. setup.sh を実行 (Xcode CLT / Homebrew / Stow / Brewfile / zsh プラグイン / tldr キャッシュを一括)
cd ~/ghq/github.com/1tsukim/dotfiles
bash setup.sh

# 3. ターミナルを再起動
```

`setup.sh` の中身:
- Xcode Command Line Tools / Homebrew インストール
- Stow で各 package を `$HOME` に symlink 展開
- `brew bundle install --file=./Brewfile` でパッケージ一括導入
- `fzf-tab` / `zsh-abbr` を `~/.config/zsh/plugins/` に clone
- `tldr --update` でキャッシュ初期化

## 普段の変更フロー

`~/.config/zsh/.zshrc` などを編集すると、symlink 経由でリポ内の実体が更新される。

```bash
cd $(ghq list -p | grep dotfiles)
git status
git add .
git commit -m "zsh: tweak fzf options"
```

### push 時のアカウント切替 (重要)

このリポは個人アカウント (`1tsukim`) の private repo。業務用アカウントを gh CLI の active 既定にしている場合、**push の時だけ手動で切替**が必要。

```bash
cd $(ghq list -p | grep dotfiles) \
  && gh auth switch -u 1tsukim \
  && git push \
  && gh auth switch -u <work-account>   # ← 元のアカウントに戻す
```

#### なぜ自動化していないか

- `~/.config/git/config` の `[includeIf "gitdir:~/ghq/github.com/1tsukim/"]` で **user.email は自動切替** されている (commit author は `285429559+1tsukim@users.noreply.github.com`)
- ただし **gh CLI の credential helper (`gh auth git-credential`) は URL ベースのアカウント自動選択をサポートしていない** ため、push 時の credentials だけは active アカウントを切り替えるしかない
- 完全自動化 (switch なし) するには SSH key 別アカウント運用 (`~/.ssh/config` の `Host github-1tsukim` 定義 + remote URL を `git@github-1tsukim:...` に変更) が必要。現在は未採用

## 含めていないもの

- **Secrets**: `~/.aws/`, `~/.ssh/`, `~/.netrc`, `~/.gnupg/`
- **State**: `~/.zsh_history`, `~/.local/state/*` (履歴・セッション)
- **Cache**: `~/.cache/*` (matplotlib, ruff, npm, tealdeer など)
- **プラグイン**: `~/.config/zsh/plugins/` (上記の手動 clone で復元)
- **AI ツール固定パス**: `~/.claude/`, `~/.cursor/`, `~/.codex/` など
