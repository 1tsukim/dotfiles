#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
project_name=$(basename "$cwd")

# ===== 描画モード判定 =====
# UTF-8 ロケールなら Unicode 記号、そうでなければ ASCII にフォールバック。
# EC2 のロケール未設定環境で `█░` 等が文字化けするのを防ぐ。
if locale 2>/dev/null | grep -qiE 'UTF-?8'; then
    use_unicode=1
else
    use_unicode=0
fi

if (( use_unicode )); then
    bar_full="█"; bar_empty="░"
    s_ok="🟢"; s_warn="🟡"; s_crit="🔴"
    s_sys="💻"; s_bot="🤖"; s_branch="🌿"; s_dir="📂"
    s_modified="📝"; s_clean="✅ Clean"; s_synced="✅ Synced"
    s_no_remote="🚫 No Remote"; s_docker="🐳"
    s_chat="💬"; s_gpu_warn="⚠️"
    arrow_up="↑"; arrow_down="↓"
else
    bar_full="#"; bar_empty="-"
    s_ok="[OK]"; s_warn="[!]"; s_crit="[X]"
    s_sys="SYS"; s_bot="MDL"; s_branch="GIT"; s_dir="DIR"
    s_modified="MOD"; s_clean="CLEAN"; s_synced="SYNCED"
    s_no_remote="NO-REMOTE"; s_docker="DOCKER"
    s_chat="TURNS"; s_gpu_warn="[!]"
    arrow_up="^"; arrow_down="v"
fi

# ===== Context window =====
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$used" ] || [ "$used" = "null" ]; then
    input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
    output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
    window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
    if [ "$window_size" -gt 0 ] 2>/dev/null; then
        total_tokens=$((input_tokens + output_tokens))
        used=$((total_tokens * 100 / window_size))
    fi
fi

# ===== Turns =====
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    turns=$(grep -c '"type":"user"' "$transcript_path" 2>/dev/null)
    [ -z "$turns" ] && turns="0"
else
    turns="0"
fi

# ===== Git branch / push status / file status =====
branch=$(git branch --show-current 2>/dev/null || echo "-")

push_status=""
if git rev-parse --abbrev-ref @{upstream} &>/dev/null; then
    counts=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    ahead=$(echo "$counts" | awk '{print $1}')
    behind=$(echo "$counts" | awk '{print $2}')

    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        push_status="${arrow_up}${ahead} ${arrow_down}${behind}"
    elif [ "$ahead" -gt 0 ]; then
        push_status="${arrow_up}${ahead}"
    elif [ "$behind" -gt 0 ]; then
        push_status="${arrow_down}${behind}"
    else
        push_status="$s_synced"
    fi
else
    push_status="$s_no_remote"
fi

git_status=$(git status --porcelain 2>/dev/null | awk \
  -v mod="$s_modified" -v clean="$s_clean" '
  /^.M/ {m++}
  /^M/ {staged++}
  /^A/ {a++}
  /^\?/ {u++}
  END {
    total = m + staged + a + u
    if (total == 0) print clean
    else printf "%s Modified:%d, Staged:%d, Untracked:%d", mod, m+0, staged+a+0, u+0
  }
')

# ===== Docker (macOS=Docker.app、Linux=dockerd プロセス or systemd service) =====
# snap/rootless docker でプロセス名が変わるケースを systemctl で拾う。
# macOS には systemctl が無いので stderr を捨て、--quiet で stdout も抑制。
docker_containers=""
if pgrep -x "Docker" >/dev/null 2>&1 \
   || pgrep -x "dockerd" >/dev/null 2>&1 \
   || systemctl is-active --quiet docker 2>/dev/null; then
    docker_containers=$(docker ps --format "{{.Names}}" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
fi

# ===== Disk =====
disk_info=$(df -h / 2>/dev/null | awk 'NR==2 {print $5, $4}')
disk_usage=$(echo "$disk_info" | awk '{print $1}' | tr -d '%')
disk_free=$(echo "$disk_info" | awk '{print $2}')
[ -z "$disk_usage" ] && disk_usage="?"
[ -z "$disk_free" ] && disk_free="?"
if [ -n "$docker_containers" ]; then
    docker_info="${s_docker} ${docker_containers}"
else
    docker_info=""
fi

# ===== Session番号 (md5 / md5sum / shasum 互換) =====
if command -v md5 &>/dev/null; then
    project_hash=$(pwd | md5 | cut -c1-8)
elif command -v md5sum &>/dev/null; then
    project_hash=$(pwd | md5sum | cut -c1-8)
else
    project_hash=$(pwd | shasum 2>/dev/null | cut -c1-8)
fi
[ -z "$project_hash" ] && project_hash="default"
session_file="$HOME/.claude/.statusline-sessions-${project_hash}"

if [ -n "$session_id" ]; then
    if [ -f "$session_file" ]; then
        session_num=$(grep -n "^${session_id}$" "$session_file" 2>/dev/null | cut -d: -f1)
    fi

    if [ -z "$session_num" ]; then
        echo "$session_id" >> "$session_file"
        session_num=$(wc -l < "$session_file" | tr -d ' ')
    fi
else
    session_num="1"
fi

# ===== CPU =====
if [[ "$OSTYPE" == "darwin"* ]]; then
    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    cpu_total=$(ps -A -o %cpu | awk '{sum+=$1} END {print sum}')
    cpu_usage=$(echo "$cpu_total $cpu_cores" | awk '{printf "%.0f", $1/$2}')
else
    cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2)}')
    [ -z "$cpu_usage" ] && cpu_usage=$(vmstat 1 2 2>/dev/null | tail -1 | awk '{print 100-$15}')
fi
[ -z "$cpu_usage" ] && cpu_usage="?"

# ===== Memory =====
if [[ "$OSTYPE" == "darwin"* ]]; then
    mem_usage=$(vm_stat 2>/dev/null | awk '
        /Pages free/ {free=$3}
        /Pages active/ {active=$3}
        /Pages inactive/ {inactive=$3}
        /Pages speculative/ {spec=$3}
        /Pages wired/ {wired=$4}
        END {
            gsub(/\./,"",free); gsub(/\./,"",active); gsub(/\./,"",inactive);
            gsub(/\./,"",spec); gsub(/\./,"",wired);
            used = (active + wired) * 4096 / 1024 / 1024 / 1024
            total = (free + active + inactive + spec + wired) * 4096 / 1024 / 1024 / 1024
            if (total > 0) printf "%.0f", (used/total)*100
        }
    ')
else
    mem_usage=$(free 2>/dev/null | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
fi
[ -z "$mem_usage" ] && mem_usage="?"

# ===== GPU =====
gpu_usage=""
gpu_error=""

if command -v nvidia-smi &>/dev/null; then
    gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    if [ -z "$gpu_usage" ]; then
        gpu_error="${s_gpu_warn}GPU検出失敗"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    gpu_usage=$(ioreg -r -d 1 -c IOAccelerator 2>/dev/null | grep -o '"Device Utilization %"=[0-9]*' | cut -d= -f2)
    [ -z "$gpu_usage" ] && gpu_usage="0"
fi

if [ -n "$gpu_error" ]; then
    gpu_display="$gpu_error"
elif [ -n "$gpu_usage" ]; then
    gpu_display="GPU${gpu_usage}%"
else
    gpu_display="${s_gpu_warn}GPU未検出"
fi

# ===== System info =====
sys_info="${s_sys} CPU${cpu_usage}% RAM${mem_usage}% Disk${disk_usage}%(${disk_free}空き) ${gpu_display}"

# ===== Context display =====
if [ -n "$used" ] && [ "$used" != "null" ]; then
    used_int=$(printf "%.0f" "$used")

    if [ "$used_int" -lt 70 ]; then
        symbol="$s_ok"
    elif [ "$used_int" -lt 90 ]; then
        symbol="$s_warn"
    else
        symbol="$s_crit"
    fi

    filled=$((used_int * 10 / 100))
    bar=$(printf "%${filled}s" | tr ' ' "$bar_full")
    empty=$(printf "%$((10 - filled))s" | tr ' ' "$bar_empty")

    ctx_display="${symbol} [${bar}${empty}] Ctx ${used_int}%"
else
    ctx_display=""
fi

# ===== Output =====
line1="#${session_num}"
[ -n "$ctx_display" ] && line1="${line1} ${ctx_display}"
line1="${line1} | ${s_chat} ${turns}回 | ${s_bot} ${model} | ${sys_info}"

line2="${s_branch} ${branch} (${push_status}) | ${s_dir} ${project_name} | ${git_status}"

printf "%s\n%s" "$line1" "$line2"

if [ -n "$docker_info" ]; then
    printf "\n%s" "$docker_info"
fi
