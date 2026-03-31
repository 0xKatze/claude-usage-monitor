#!/bin/bash
# Claude Code Custom Status Line — claude-usage-monitor plugin
# Shows: [Model] ▓▓░░░ 42%/1M | $2.10($3.75/d) 30m +15-3 | 5h:12%(45m) 7d:8%
#
# Config: COST_DECIMALS env var or ~/.claude/usage-monitor.conf
#   echo "COST_DECIMALS=2" > ~/.claude/usage-monitor.conf

input=$(cat)

# --- Config: cost decimal places (default: 4) ---
CONF="$HOME/.claude/usage-monitor.conf"
[ -f "$CONF" ] && source "$CONF"
COST_DECIMALS="${COST_DECIMALS:-${CLAUDE_PLUGIN_OPTION_cost_decimals:-2}}"

# --- Parse JSON ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"' | sed 's/Claude //')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
COST_RAW=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST=$(printf "%.${COST_DECIMALS}f" "$COST_RAW")
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
RATE_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RATE_5H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RATE_7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
RATE_7D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

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
    if [ "$CD" = "$(date +%Y-%m-%d)" ]; then
        DC_RAW=$(tail -1 "$CACHE" 2>/dev/null)
        DC=$(printf "%.${COST_DECIMALS}f" "$DC_RAW")
    fi
fi

# --- Build output ---
O="${DIM}[${RST}${CYN}${MODEL}${RST}${DIM}]${RST} "
O+="${BC}${BAR}${RST} ${CC}${CTX_PCT}%${RST}${DIM}/${CL}${RST}"
O+=" ${DIM}|${RST} ${MAG}\$${COST}${RST}"
[ -n "$DC" ] && [ "$DC" != "0" ] && O+="${DIM}(\$${DC}/d)${RST}"
[ "$MINS" -gt 0 ] && O+=" ${DIM}${MINS}m${RST}"
([ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]) && O+=" ${GRN}+${LINES_ADD}${RST}${RED}-${LINES_DEL}${RST}"
# Plan usage (5h + 7d rate limits)
if [ -n "$RATE_5H" ] || [ -n "$RATE_7D" ]; then
    O+=" ${DIM}|${RST}"

    # 5-hour window
    if [ -n "$RATE_5H" ]; then
        RI5=$(echo "$RATE_5H" | cut -d. -f1)
        [ "$RI5" -ge 80 ] && R5C="${RED}" || { [ "$RI5" -ge 50 ] && R5C="${YLW}" || R5C="${GRN}"; }
        O+=" ${R5C}5h:${RI5}%${RST}"
        # Reset countdown
        if [ -n "$RATE_5H_RESET" ] && [ "$RATE_5H_RESET" != "null" ] && [ "$RI5" -ge 50 ]; then
            NOW=$(date +%s)
            LEFT=$(( (RATE_5H_RESET / 1000 - NOW) / 60 ))
            [ "$LEFT" -gt 0 ] && O+="${DIM}(${LEFT}m)${RST}"
        fi
    fi

    # 7-day window
    if [ -n "$RATE_7D" ]; then
        RI7=$(echo "$RATE_7D" | cut -d. -f1)
        [ "$RI7" -ge 80 ] && R7C="${RED}" || { [ "$RI7" -ge 50 ] && R7C="${YLW}" || R7C="${DIM}"; }
        O+=" ${R7C}7d:${RI7}%${RST}"
    fi
fi

echo -e "$O"
