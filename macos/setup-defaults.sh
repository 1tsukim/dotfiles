#!/usr/bin/env bash
# macOS デフォルト設定（idempotent。何度実行しても同じ結果になる）
# Mathias Bynens (https://mths.be/macos) → driesvints/dotfiles から厳選。
# 実行: bash macos/setup-defaults.sh
# 注意: 最後に Finder / Dock / SystemUIServer / cfprefsd を killall する。
#       Timezone 設定で sudo パスワード入力が必要。

set -eu

# System Preferences が開いていると上書きされるので閉じる
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true

# sudo タイムスタンプを先取り（タイムゾーン設定で必要）
sudo -v

###############################################################################
# General UI/UX                                                               #
###############################################################################

# ウィンドウリサイズの引っ掛かりを除去
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# 保存パネル・印刷パネルをデフォルトで詳細表示
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# 印刷終了後にプリンタアプリを自動終了
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Help Viewer を非フローティング（他ウィンドウに被らない）
defaults write com.apple.helpviewer DevMode -bool true

# コード書く時に邪魔な自動変換を無効化
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false   # smart dashes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false  # smart quotes
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false # auto-correct

###############################################################################
# Trackpad, keyboard, Bluetooth                                               #
###############################################################################

# Bluetooth ヘッドセット音質向上
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

# Tab で全コントロールを選択可能に（モーダルでも Tab 移動）
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# キーリピート最速化（mathiasbynens 由来）
# UI 最速は KeyRepeat=2 / InitialKeyRepeat=15。以下は UI から設定不可な隠し最速値。
# 反映はログアウト → ログインが必要（killall では効かない）。
defaults write NSGlobalDomain KeyRepeat -int 1               # リピート間隔（小さいほど速い）
defaults write NSGlobalDomain InitialKeyRepeat -int 10       # リピート開始までの遅延
# 長押しでアクセント文字メニューを出す機能を OFF（OFF にしないと KeyRepeat 設定がそもそも効かない）
# 副作用: à / á 等のアクセント文字長押し入力が使えなくなる（フランス語・スペイン語書きでなければ無問題）
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# 言語・ロケール・タイムゾーン（日本）
defaults write NSGlobalDomain AppleLanguages -array "ja" "en"
defaults write NSGlobalDomain AppleLocale -string "ja_JP@currency=JPY"
sudo systemsetup -settimezone "Asia/Tokyo" > /dev/null

###############################################################################
# Screen                                                                       #
###############################################################################

# スクリーンセーバー後・スリープ後にパスワード即要求
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

###############################################################################
# Finder                                                                       #
###############################################################################

# Finder の全アニメーション無効化（速い）
defaults write com.apple.finder DisableAllAnimations -bool true

# パスバー表示
defaults write com.apple.finder ShowPathbar -bool true

# ステータスバー表示（ファイル数 / ディスク残量）
defaults write com.apple.finder ShowStatusBar -bool true

# 拡張子を常時表示（.app / .png 等が Finder で見えるように）
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# フォルダ先頭ソート
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# 検索デフォルトを「現フォルダ」に
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# 拡張子変更時の警告無効
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# ネットワーク / USB に .DS_Store を書かない（共有フォルダを汚さない）
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# デスクトップのアイコンを snap-to-grid、間隔 100、サイズ 80
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true

# Finder のデフォルト表示をリスト表示に
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# ~/Library を可視化（開発者必須）
chflags nohidden ~/Library
xattr -d com.apple.FinderInfo ~/Library 2>/dev/null || true

# File Info パネルの General / Open with / Privileges をデフォルト展開
defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true \
    OpenWith -bool true \
    Privileges -bool true

###############################################################################
# Dock                                                                         #
###############################################################################

# ウィンドウをアプリアイコンに最小化（Dock を埋めない）
defaults write com.apple.dock minimize-to-application -bool true

# アプリ起動アニメーション無効
defaults write com.apple.dock launchanim -bool false

# Spaces を自動並び替えしない（位置固定）
defaults write com.apple.dock mru-spaces -bool false

# 最近使ったアプリを Dock に出さない
defaults write com.apple.dock show-recents -bool false

###############################################################################
# iTerm2                                                                       #
###############################################################################
# 「点滅する緑の縦棒カーソル」を全プロファイルに適用。
# 前提: iTerm2 を一度起動してプロファイルが生成済みであること。
# 起動中の場合は plist 上書きが in-memory 値に潰されるので一度終了する。

ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
if [ -f "$ITERM_PLIST" ]; then
    osascript -e 'tell application "iTerm" to quit' 2>/dev/null || true
    sleep 1

    # プロファイル配列 ("New Bookmarks") の各要素に Name フィールドの存在で順次到達
    i=0
    while /usr/libexec/PlistBuddy -c "Print :'New Bookmarks':$i:Name" "$ITERM_PLIST" >/dev/null 2>&1; do
        # Cursor Type: 0=Underline / 1=Vertical bar / 2=Box
        /usr/libexec/PlistBuddy -c "Set :'New Bookmarks':$i:'Cursor Type' 1" "$ITERM_PLIST" 2>/dev/null \
            || /usr/libexec/PlistBuddy -c "Add :'New Bookmarks':$i:'Cursor Type' integer 1" "$ITERM_PLIST" 2>/dev/null
        /usr/libexec/PlistBuddy -c "Set :'New Bookmarks':$i:'Blinking Cursor' 1" "$ITERM_PLIST" 2>/dev/null \
            || /usr/libexec/PlistBuddy -c "Add :'New Bookmarks':$i:'Blinking Cursor' integer 1" "$ITERM_PLIST" 2>/dev/null

        # カーソル色: #33ff33 (R=0.2, G=1.0, B=0.2)。Light/Dark mode 双方とも同色
        for key in "Cursor Color" "Cursor Color (Dark)" "Cursor Color (Light)"; do
            /usr/libexec/PlistBuddy -c "Set :'New Bookmarks':$i:'$key':'Red Component' 0.2" "$ITERM_PLIST" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Set :'New Bookmarks':$i:'$key':'Green Component' 1.0" "$ITERM_PLIST" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Set :'New Bookmarks':$i:'$key':'Blue Component' 0.2" "$ITERM_PLIST" 2>/dev/null || true
        done
    done
else
    echo "  - iTerm2 plist 未生成: iTerm2 を一度起動してから setup-defaults.sh を再実行してください (skip)"
fi

###############################################################################
# 反映                                                                         #
###############################################################################

# 変更を反映するため関連プロセスを kill
for app in "Finder" "Dock" "SystemUIServer" "cfprefsd"; do
  killall "${app}" &>/dev/null || true
done

echo "✓ macOS defaults applied. ターミナルを再起動するか exec zsh -l してください"
