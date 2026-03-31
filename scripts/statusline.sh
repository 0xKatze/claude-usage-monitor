#!/bin/bash
# Claude Code Custom Status Line — claude-usage-monitor plugin
# Shows: [Model] ▓▓▓░░ 42%/1M | $1.23($5/day) 30m +15/-3 | 5h:12%

input=$(cat)

# --- Parse JSON ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"' | sed 's/Claude //')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
RATE_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# --- Colors ---
RST='\033[0m'; DIM='\033[2m'; BOLD='\033[1m'
GRN='\033[32m'; YLW='\033[33m'; RED='\033[31m'; CYN='\033[36m'; MAG='\033[35m'

# --- Context bar (5 chars) ---
FILLED=$((CTX_PCT / 20)); EMPTY=$((5 - FILLED))
BAR=""; for ((i=0;i<FILLED;i++)); do BAR+="▓"; done; for ((i=0;i<EMPTY;i++)); do BAR+="░"; done

if [ "$CTX_PCT" -ge 80 ]; then CC="${BOLD}${RED}"; BC="${RED}"
elif [ "$CTX_PCT" -ge 60 ]; then CC="${YLW}"; BC="${YLW}"
else CC="${GRN}"; BC="${GRN}"; fi

# Context size label
[ "$CTX_SIZE" -ge 1000000 ] && CL="1M" || CL="200k"

# Duration
MINS=$((DURATION_MS / 60000))

# ccusage daily cost (from cache)
CACHE="/tmp/.ccusage_today_cost"
DC=""
if [ -f "$CACHE" ]; then
    CD=$(head -1 "$CACHE" 2>/dev/null)
    [ "$CD" = "$(date +%Y-%m-%d)" ] && DC=$(tail -1 "$CACHE" 2>/dev/null)
fi

# --- Build output ---
O="${DIM}[${RST}${CYN}${MODEL}${RST}${DIM}]${RST} "
O+="${BC}${BAR}${RST} ${CC}${CTX_PCT}%${RST}${DIM}/${CL}${RST}"
O+=" ${DIM}|${RST} ${MAG}\$${COST}${RST}"
[ -n "$DC" ] && [ "$DC" != "0" ] && O+="${DIM}(\$${DC}/d)${RST}"
[ "$MINS" -gt 0 ] && O+=" ${DIM}${MINS}m${RST}"
([ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]) && O+=" ${GRN}+${LINES_ADD}${RST}${RED}-${LINES_DEL}${RST}"
if [ -n "$RATE_5H" ]; then
    RI=$(echo "$RATE_5H" | cut -d. -f1)
    [ "$RI" -ge 80 ] && RC="${RED}" || { [ "$RI" -ge 50 ] && RC="${YLW}" || RC="${DIM}"; }
    O+=" ${DIM}|${RST} ${RC}5h:${RI}%${RST}"
fi

echo -e "$O"
