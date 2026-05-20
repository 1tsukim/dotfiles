# ~/.zshenv — 全 zsh 起動で最初に読まれる。XDG Base Directory の宣言はここ。
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# ツール別の XDG 誘導
export IPYTHONDIR="$XDG_CONFIG_HOME/ipython"
export JUPYTER_CONFIG_DIR="$XDG_CONFIG_HOME/jupyter"
export JUPYTER_DATA_DIR="$XDG_DATA_HOME/jupyter"
export MPLCONFIGDIR="$XDG_CACHE_HOME/matplotlib"
export RUFF_CACHE_DIR="$XDG_CACHE_HOME/ruff"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"

# zsh: 設定一式は ZDOTDIR、履歴は XDG_STATE_HOME
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export SHELL_SESSION_DIR="$XDG_STATE_HOME/zsh/sessions"

# npm: 設定/キャッシュ/ログを XDG へ (prefix は Homebrew 配下なのでそのまま)
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_LOGS_DIR="$XDG_STATE_HOME/npm/logs"

# zsh-abbr: ユーザー略語定義ファイル (手書き + abbr add 経由の自動追記)
export ABBR_USER_ABBREVIATIONS_FILE="$XDG_CONFIG_HOME/zsh/.abbr"
export TEALDEER_CONFIG_DIR="$XDG_CONFIG_HOME/tealdeer"

# ─── App env（子プロセス・SSH・cron 等にも継承させたい変数）───
# ロケール（SSH 先・Docker・cron で文字化け防止）
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# Editor（git/crontab 等が読む）
export EDITOR="cursor --wait"
export VISUAL="cursor --wait"

# Homebrew
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_BUNDLE_FILE="$HOME/ghq/github.com/1tsukim/dotfiles/Brewfile"

# Claude Code
export CLAUDE_API_PROVIDER="anthropic"
export CLAUDE_CODE_USE_BEDROCK=0
