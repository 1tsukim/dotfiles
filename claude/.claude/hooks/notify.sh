#!/bin/bash
# Claude Code 通知 hook（音 + osascript 通知 + cmux 通知の3経路を一元化）
# usage: notify.sh <event>
#   event: notification | stop | subagent-stop
# osascript の subtitle にプロジェクト名（basename $PWD）を入れる
# cmux の subtitle は既存のステータス表示を維持し、body 先頭にプロジェクト名を付与

EVENT="$1"
PROJECT="$(basename "$PWD")"

case "$EVENT" in
  notification)
    afplay /System/Library/Sounds/Ping.aiff
    osascript -e "display notification \"確認してや\" with title \"Claude Code\" subtitle \"$PROJECT\""
    cmux notify --title 'Claude Code' --subtitle '入力待ち' --body "$PROJECT: 確認してや" 2>/dev/null || true
    ;;
  stop)
    afplay /System/Library/Sounds/Glass.aiff
    osascript -e "display notification \"応答完了しました\" with title \"Claude Code\" subtitle \"$PROJECT\""
    cmux notify --title 'Claude Code' --subtitle 'タスク完了' --body "$PROJECT: 応答完了" 2>/dev/null || true
    ;;
  subagent-stop)
    afplay /System/Library/Sounds/Pop.aiff
    cmux notify --title 'Claude Code' --subtitle 'サブエージェント完了' --body "$PROJECT: サブタスク終了" 2>/dev/null || true
    ;;
esac

exit 0
