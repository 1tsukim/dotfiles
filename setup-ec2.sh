#!/usr/bin/env bash
# EC2 / Ubuntu 用セットアップスクリプト (macOS 用 setup.sh の Linux 版)
# 想定実行手順:
#   1. ghq get 1tsukim/dotfiles (or git clone してから ghq import)
#   2. cd ~/ghq/github.com/1tsukim/dotfiles
#   3. bash setup-ec2.sh
#
# 冪等。再実行しても害なし。

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${YELLOW}==> $*${NC}"; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${RED}! $*${NC}"; }

if ! command -v apt-get &>/dev/null; then
    warn "このスクリプトは apt (Ubuntu/Debian) 専用です"
    exit 1
fi

# 1. apt パッケージ
info "Installing apt packages..."
sudo apt-get update -qq
sudo apt-get install -y \
    trash-cli \
    fd-find \
    bat \
    tmux \
    fzf \
    jq \
    git \
    nano \
    locales \
    stow \
    ripgrep \
    libnotify-bin
ok "apt packages installed"

# 2. eza (Ubuntu 24.04+ の apt にあり、無ければ GitHub release から /usr/local/bin)
if ! command -v eza &>/dev/null; then
    info "Installing eza..."
    if sudo apt-get install -y eza 2>/dev/null; then
        ok "eza installed via apt"
    else
        EZA_VER=$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/eza-community/eza/releases/download/${EZA_VER}/eza_x86_64-unknown-linux-gnu.tar.gz" \
            | sudo tar -xz -C /usr/local/bin eza
        sudo chmod +x /usr/local/bin/eza
        ok "eza ${EZA_VER} installed from GitHub release"
    fi
else
    ok "eza already installed"
fi

# 3. fd / bat の symlink (Debian/Ubuntu ではバイナリ名が fdfind / batcat)
mkdir -p "$HOME/.local/bin"
if command -v fdfind &>/dev/null && [ ! -e "$HOME/.local/bin/fd" ]; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    ok "fd → fdfind symlink"
fi
if command -v batcat &>/dev/null && [ ! -e "$HOME/.local/bin/bat" ]; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    ok "bat → batcat symlink"
fi

# 4. Claude Code hooks / statusline に +x を付ける
# macOS から cp/rsync 系で持ってきた場合に mode bit が落ちるケース対策
info "Setting +x on Claude Code hooks / statusline..."
if [ -d "$HOME/.claude/hooks" ]; then
    chmod +x "$HOME/.claude/hooks/"*.sh 2>/dev/null || true
fi
[ -f "$HOME/.claude/statusline-command.sh" ] && chmod +x "$HOME/.claude/statusline-command.sh"
ok "+x applied"

# 5. UTF-8 ロケールを有効化 (statusline / 絵文字の文字化け対策)
info "Enabling UTF-8 locales..."
sudo locale-gen en_US.UTF-8 ja_JP.UTF-8 2>/dev/null || true
sudo update-locale LANG=en_US.UTF-8 2>/dev/null || true
ok "locales generated"

ok "EC2 setup complete!"
warn "新シェルを開いて反映 (exec zsh -l) と、~/.local/bin が PATH に入っているか確認してください"
