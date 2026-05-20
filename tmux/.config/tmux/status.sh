#!/bin/zsh
# tmux status-right 用ヘルパー
# CPU使用率(%) / 物理メモリ使用量 / バッテリー残量(%) を1行で出力

# top を1回だけ呼んでCPUとMEMを同時取得 (subprocess削減)
top_out=$(top -l 1 -n 0 2>/dev/null)

# CPU: user + sys (idle以外) を整数化
cpu=$(echo "$top_out" | awk '/CPU usage/ {gsub("%",""); printf "%.0f", $3+$5}')

# MEM: used値 (例 "15G")
mem=$(echo "$top_out" | awk '/PhysMem/ {print $2}')

# BAT: pmset から % だけ抽出。バッテリー無しなら空欄
bat=$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1)

if [[ -n "$bat" ]]; then
    printf "CPU %s%% │ MEM %s │ BAT %s" "$cpu" "$mem" "$bat"
else
    printf "CPU %s%% │ MEM %s" "$cpu" "$mem"
fi
