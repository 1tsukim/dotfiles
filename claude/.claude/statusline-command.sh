#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
project_name=$(basename "$cwd")

# Get context window info
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

# Count user turns from transcript
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    turns=$(grep -c '"type":"user"' "$transcript_path" 2>/dev/null)
    [ -z "$turns" ] && turns="0"
else
    turns="0"
fi

# Git branch
branch=$(git branch --show-current 2>/dev/null || echo "-")

# Git push status (ahead/behind)
push_status=""
if git rev-parse --abbrev-ref @{upstream} &>/dev/null; then
    counts=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    ahead=$(echo "$counts" | awk '{print $1}')
    behind=$(echo "$counts" | awk '{print $2}')
    
    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        push_status="↑${ahead} ↓${behind}"
    elif [ "$ahead" -gt 0 ]; then
        push_status="↑${ahead}"
    elif [ "$behind" -gt 0 ]; then
        push_status="↓${behind}"
    else
        push_status="✅ Synced"
    fi
else
    push_status="🚫 No Remote"
fi

# Git status (Modified, Staged, Untracked)
git_status=$(git status --porcelain 2>/dev/null | awk '
  /^.M/ {m++}
  /^M/ {staged++}
  /^A/ {a++}
  /^\?/ {u++}
  END {
    total = m + staged + a + u
    if (total == 0) print "✅ Clean"
    else printf "📝 Modified:%d, Staged:%d, Untracked:%d", m+0, staged+a+0, u+0
  }
')

# Docker containers (up) - check if Docker process is running first (fast check)
if pgrep -x "Docker" >/dev/null 2>&1; then
    docker_containers=$(docker ps --format "{{.Names}}" 2>/dev/null | tr '\n' ' ' | sed 's/ $//');
else
    docker_containers=""
fi

# Disk usage (percentage and free space)
disk_info=$(df -h / 2>/dev/null | awk 'NR==2 {print $5, $4}')
disk_usage=$(echo "$disk_info" | awk '{print $1}' | tr -d '%')
disk_free=$(echo "$disk_info" | awk '{print $2}')
[ -z "$disk_usage" ] && disk_usage="?"
[ -z "$disk_free" ] && disk_free="?"
if [ -n "$docker_containers" ]; then
    docker_info="🐳 ${docker_containers}"
else
    docker_info=""
fi

# Session number tracking (1,2,3... per project)
project_hash=$(pwd | md5 2>/dev/null || echo "$cwd" | md5sum 2>/dev/null | cut -c1-8)
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

# CPU usage (cross-platform)
if [[ "$OSTYPE" == "darwin"* ]]; then
    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    cpu_total=$(ps -A -o %cpu | awk '{sum+=$1} END {print sum}')
    cpu_usage=$(echo "$cpu_total $cpu_cores" | awk '{printf "%.0f", $1/$2}')
else
    cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2)}')
    [ -z "$cpu_usage" ] && cpu_usage=$(vmstat 1 2 2>/dev/null | tail -1 | awk '{print 100-$15}')
fi
[ -z "$cpu_usage" ] && cpu_usage="?"

# Memory usage (cross-platform)
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

# GPU usage (try multiple methods)
gpu_usage=""
gpu_error=""

if command -v nvidia-smi &>/dev/null; then
    gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    if [ -z "$gpu_usage" ]; then
        gpu_error="⚠️GPU検出失敗"
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
    gpu_display="⚠️GPU未検出"
fi

# Combined CPU/RAM/GPU/Disk display
sys_info="💻 CPU${cpu_usage}% RAM${mem_usage}% Disk${disk_usage}%(${disk_free}空き) ${gpu_display}"

# Build context display
if [ -n "$used" ] && [ "$used" != "null" ]; then
    used_int=$(printf "%.0f" "$used")

    if [ "$used_int" -lt 70 ]; then
        symbol="🟢"
    elif [ "$used_int" -lt 90 ]; then
        symbol="🟡"
    else
        symbol="🔴"
    fi

    filled=$((used_int * 10 / 100))
    bar=$(printf "%${filled}s" | tr ' ' '█')
    empty=$(printf "%$((10 - filled))s" | tr ' ' '░')

    ctx_display="${symbol} [${bar}${empty}] Ctx ${used_int}%"
else
    ctx_display=""
fi

# Line 1: session, context, turns, model, system
line1="#${session_num}"
[ -n "$ctx_display" ] && line1="${line1} ${ctx_display}"
line1="${line1} | 💬 ${turns}回 | 🤖 ${model} | ${sys_info}"

# Line 2: branch, push status, project name, git status
line2="🌿 ${branch} (${push_status}) | 📂 ${project_name} | ${git_status}"

# Output
printf "%s\n%s" "$line1" "$line2"

# Line 3: docker (if any)
if [ -n "$docker_info" ]; then
    printf "\n%s" "$docker_info"
fi
