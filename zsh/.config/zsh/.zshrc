# 環境変数は .zshenv（継承させたい）/ .zprofile（Keychain 由来）へ移管済み。
# このファイルは対話シェル設定（setopt / 補完 / プラグイン）のみ。

# cdなしでディレクトリ移動
setopt auto_cd

setopt auto_pushd
# pushd スタックの重複排除（dirs -v を綺麗に保つ）
setopt pushd_ignore_dups

# 同じコマンドをヒストリに残さない（メモリ上の重複排除）
setopt hist_ignore_all_dups
# ファイル書込時にも重複排除（hist_ignore_all_dups の補強、再ログイン後も効く）
setopt hist_save_no_dups
# 連続空白を圧縮して保存（"ls   -la" → "ls -la"）
setopt hist_reduce_blanks
# history / fc コマンド自体を履歴に残さない（履歴調査が履歴を汚さない）
setopt hist_no_store
# 全 zsh セッションで履歴を即時共有（cmux pane 跨ぎで打ったコマンドが即出る）
setopt share_history
# 以下のパターンに完全一致するコマンドは履歴に追加しない（ノイズ除去）
#   - 標準: bg/fg/cd/clear/exit/fg/history/pwd/z
#   - ls 系: ls/ll/la/lt
#   - cd 短縮: .. / ... / ....  / desktop
#   - アプリ起動 1 文字 alias: n/c/v/s/b/f/q/e
#   - venv 起動: act
HISTORY_IGNORE='(act|b|bg|c|cd|cd ..|cd -|clear|desktop|e|exit|f|fg|history|l|la|ll|ls|lt|n|pwd|q|s|v|z|..|...|....)'

# 対話シェルで # コメントを許可（長コマンド整形・docs 用に末尾コメント可能に）
setopt interactive_comments

# 補完で小文字でも大文字にマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'


export PATH="$HOME/.local/bin:$PATH"

# zoxide: 履歴ベースのスマートな cd（z <部分文字列>, zi で対話選択）
eval "$(zoxide init zsh)"

# fzf: fuzzy finder（Ctrl-R: 履歴, Ctrl-T: ファイル, Alt-C: ディレクトリ）
source <(fzf --zsh)

# Ctrl-S/Ctrl-Q による画面フリーズを無効化（端末入力時のみ）
if [[ -t 0 ]]; then
  stty stop undef
  stty start undef
fi

# direnv: ディレクトリごとに環境変数・venv 等を自動切替（.envrc を読む）
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# fzf 強化: rg/bat/eza 連携で Ctrl-T / Alt-C のプレビューを有効化
if command -v rg &> /dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
fi
export FZF_DEFAULT_OPTS='--height 60% --layout=reverse --border --info=inline'
if command -v bat &> /dev/null; then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
fi
if command -v eza &> /dev/null; then
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
fi
# bat: TwoDarkテーマ（mizchi の dotfiles 由来）
export BAT_THEME="TwoDark"

# fzf-tab: タブ補完を fzf 画面で（compinit 必須・autosuggestions 等より前にロード）
autoload -Uz compinit && compinit
source "$ZDOTDIR/plugins/fzf-tab/fzf-tab.plugin.zsh"

# zsh-abbr: 略語を Space/Enter で実コマンドに展開（履歴に展開後の形が残る）
source "$ZDOTDIR/plugins/zsh-abbr/zsh-abbr.plugin.zsh"

# zsh-autosuggestions: 履歴ベースの ghost text 提案（→ キーで受け入れ）
source "$ZDOTDIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath'

# マシン固有設定（local.zsh: env var、git 管理外）と secrets.zsh（認証情報、任意）
# .function / .alias より先に読んで、関数・alias から env var を参照できるようにする
[ -f $ZDOTDIR/local.zsh ] && source $ZDOTDIR/local.zsh
[ -f $ZDOTDIR/secrets.zsh ] && source $ZDOTDIR/secrets.zsh

# シェル関数集（zsh 専用）と alias 集を読み込む
[ -f $ZDOTDIR/.function ] && source $ZDOTDIR/.function
[ -f $ZDOTDIR/.alias ] && source $ZDOTDIR/.alias
