#!/bin/bash
# Claude Code 通知 hook（OS 別: macOS=音+osascript / Linux=notify-send (display あれば) + ログ。cmux は両 OS 試行）
# usage: notify.sh <event>
#   event: notification | stop | subagent-stop

EVENT="$1"
PROJECT="$(basename "$PWD")"
LOGFILE="$HOME/.claude/notify.log"

is_mac() { [[ "$OSTYPE" == "darwin"* ]]; }

# X11 か Wayland のセッションがあれば true。EC2 等のヘッドレスでは false。
has_display() { [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; }

log_event() {
    mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null
    printf '[%s] %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EVENT" "$1" >> "$LOGFILE"
}

mac_notify() {
    local sound="$1" body="$2" subtitle="$3"
    afplay "/System/Library/Sounds/${sound}.aiff" 2>/dev/null || true
    [ -n "$body" ] && osascript -e "display notification \"$body\" with title \"Claude Code\" subtitle \"$subtitle\"" 2>/dev/null || true
}

# Linux 側: ヘッドレス EC2 でも「即気づく」ために 4 段重ね
#   (1) notify-send: X11/Wayland があれば GUI 通知 (DBus 経由)
#   (2) ターミナルベル: 端末まで BEL を流し audible/visual bell を起こす (ssh 越しでも届く)
#   (3) tmux display-message: tmux セッション内ならステータスバーに表示
#   (4) ログ追記: 事後参照用
linux_notify() {
    local body="$1" subtitle="$2"
    if has_display && command -v notify-send &>/dev/null; then
        notify-send "Claude Code" "${subtitle}: ${body}" 2>/dev/null || true
    fi
    printf '\a' > /dev/tty 2>/dev/null || true
    if [[ -n "${TMUX:-}" ]] && command -v tmux &>/dev/null; then
        tmux display-message -d 3000 "Claude: ${subtitle} — ${body}" 2>/dev/null || true
    fi
    log_event "${subtitle}: ${body}"
}

case "$EVENT" in
  notification)
    if is_mac; then
        mac_notify Ping "確認してや" "$PROJECT"
    else
        linux_notify "確認してや" "$PROJECT"
    fi
    cmux notify --title 'Claude Code' --subtitle '入力待ち' --body "$PROJECT: 確認してや" 2>/dev/null || true
    ;;
  stop)
    if is_mac; then
        mac_notify Glass "応答完了しました" "$PROJECT"
    else
        linux_notify "応答完了" "$PROJECT"
    fi
    cmux notify --title 'Claude Code' --subtitle 'タスク完了' --body "$PROJECT: 応答完了" 2>/dev/null || true
    ;;
  subagent-stop)
    if is_mac; then
        mac_notify Pop "" ""
    else
        linux_notify "サブタスク終了" "$PROJECT"
    fi
    cmux notify --title 'Claude Code' --subtitle 'サブエージェント完了' --body "$PROJECT: サブタスク終了" 2>/dev/null || true
    ;;
esac

exit 0
