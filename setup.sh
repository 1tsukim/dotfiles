#!/usr/bin/env bash
# dotfiles の新マシンセットアップスクリプト
# 想定実行手順:
#   1. ghq get 1tsukim/dotfiles   (または git clone してから ghq import)
#   2. cd ~/ghq/github.com/1tsukim/dotfiles
#   3. bash setup.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${YELLOW}==> $*${NC}"; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${RED}! $*${NC}"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# 1. Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    info "Installing Xcode Command Line Tools..."
    xcode-select --install
    warn "ダイアログで承認 → インストール完了後に setup.sh を再実行してください"
    exit 0
else
    ok "Xcode CLT installed"
fi

# 2. Homebrew
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    ok "Homebrew installed"
fi

# 3. Stow (Brewfile より先に入れる: Stow で ~/.Brewfile を symlink するため)
if ! command -v stow &>/dev/null; then
    info "Installing Stow..."
    brew install stow
else
    ok "Stow installed"
fi

# 4. Stow で symlink 展開
info "Stowing dotfile packages..."
PACKAGES=(zsh git tmux tealdeer karabiner claude codex cmux cursor ghostty bin)
for pkg in "${PACKAGES[@]}"; do
    [ -d "$pkg" ] || continue
    stow --target="$HOME" --restow "$pkg" 2>&1 | grep -v "^$" || true
done
ok "Stow done"

# 4.5. local 設定ファイルを template から初回コピー（既存なら触らない）
# *.example は公開、実体ファイル (.gitignore 済) は machine-local
copy_if_missing() {
    local dst="$1" src="$2"
    if [ ! -f "$dst" ] && [ -f "$src" ]; then
        cp "$src" "$dst"
        info "Created $dst from $(basename "$src")"
    fi
}
copy_if_missing "$DOTFILES_DIR/zsh/.config/zsh/local.zsh"      "$DOTFILES_DIR/zsh/.config/zsh/local.zsh.example"
copy_if_missing "$DOTFILES_DIR/git/.config/git/config.local"   "$DOTFILES_DIR/git/.config/git/config.local.example"
copy_if_missing "$DOTFILES_DIR/codex/.codex/config.toml"       "$DOTFILES_DIR/codex/.codex/config.toml.example"
ok "local templates ready"

# 4.6. Claude Code memory + skills は private companion repo (個人用) で管理
# fork 者 / 他マシン（権限なし）の場合は clone 失敗が想定内、skip して継続する
CLAUDE_CONTEXT_DIR="$HOME/ghq/github.com/1tsukim/claude-context"
if [ ! -d "$CLAUDE_CONTEXT_DIR" ]; then
    info "Trying to clone optional companion repo for Claude Code memory / skills..."
    if ghq get https://github.com/1tsukim/claude-context.git 2>/dev/null; then
        ok "companion repo cloned"
    else
        info "companion repo skipped (private、fork 者なら想定通り)"
    fi
fi
if [ -d "$CLAUDE_CONTEXT_DIR" ]; then
    (cd "$CLAUDE_CONTEXT_DIR" && stow --target="$HOME" --restow claude 2>&1 | grep -v "^$" || true)
    ok "companion repo stowed"
fi

# 5. Brewfile から残りのパッケージを一括インストール
info "Installing packages from $DOTFILES_DIR/Brewfile ..."
brew bundle install --file="$DOTFILES_DIR/Brewfile"
ok "brew bundle done"

# 6. zsh プラグインを clone (このリポには含めていない)
PLUGINS_DIR="$HOME/.config/zsh/plugins"
mkdir -p "$PLUGINS_DIR"

if [ ! -d "$PLUGINS_DIR/fzf-tab" ]; then
    info "Cloning fzf-tab..."
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$PLUGINS_DIR/fzf-tab"
else
    ok "fzf-tab already installed"
fi

if [ ! -d "$PLUGINS_DIR/zsh-abbr" ]; then
    info "Cloning zsh-abbr (+ submodule)..."
    git clone --depth=1 --recurse-submodules https://github.com/olets/zsh-abbr "$PLUGINS_DIR/zsh-abbr"
else
    ok "zsh-abbr already installed"
fi

if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
    info "Cloning zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
else
    ok "zsh-autosuggestions already installed"
fi

# 7. tldr (tealdeer) のキャッシュ初期化
if command -v tldr &>/dev/null; then
    info "Updating tldr cache..."
    mkdir -p "$HOME/.cache/tealdeer"
    tldr --update >/dev/null
    ok "tldr cache initialized"
fi

# 8. 後片付け: zcompdump は新環境で再生成されるので存在すれば削除
[ -f "$HOME/.zcompdump" ] && \rm -f "$HOME/.zcompdump"

ok "Setup complete!"
warn "ターミナルを再起動してください (新ウィンドウを開く or exec zsh -l)"
warn "Karabiner-Elements / Raycast などの GUI アプリは初回起動時に macOS の許可ダイアログが出ます"
info "macOS のデフォルト設定を反映するには: bash macos/setup-defaults.sh"
