#!/bin/bash
# Claude Code Custom Status Line — claude-usage-monitor plugin
# ╭ Opus 4.6 ╮ ████░░░░░░ 42% ◆ $2.10 ‹$3.75/d› ◆ 30m ◆ +15 -3 │ 5h 12% ⟳45m │ 7d 8%
#
# Config: ~/.claude/usage-monitor.conf
#   COST_DECIMALS=2   (default)
#   BAR_WIDTH=10      (default)

input=$(cat)

# --- Config ---
CONF="$HOME/.claude/usage-monitor.conf"
[ -f "$CONF" ] && source "$CONF"
COST_DECIMALS="${COST_DECIMALS:-${CLAUDE_PLUGIN_OPTION_cost_decimals:-2}}"
BAR_WIDTH="${BAR_WIDTH:-10}"

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

# --- Colors ---
RST='\033[0m'; DIM='\033[2m'; BOLD='\033[1m'
GRN='\033[32m'; YLW='\033[33m'; RED='\033[31m'; CYN='\033[36m'; MAG='\033[35m'; WHT='\033[37m'
BG_DIM='\033[48;5;236m'  # dark gray background for bar

# --- Helpers ---
color_by_pct() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then echo "${BOLD}${RED}"
    elif [ "$pct" -ge 60 ]; then echo "${YLW}"
    else echo "${GRN}"; fi
}

# --- Context bar (fine-grained with partial blocks) ---
BLOCKS=("░" "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")
FILLED_FULL=$(( CTX_PCT * BAR_WIDTH / 100 ))
REMAINDER=$(( (CTX_PCT * BAR_WIDTH * 8 / 100) % 8 ))
EMPTY_FULL=$(( BAR_WIDTH - FILLED_FULL - (REMAINDER > 0 ? 1 : 0) ))

CTX_COLOR=$(color_by_pct "$CTX_PCT")
BAR=""
for ((i=0; i<FILLED_FULL; i++)); do BAR+="█"; done
[ "$REMAINDER" -gt 0 ] && BAR+="${BLOCKS[$REMAINDER]}"
for ((i=0; i<EMPTY_FULL; i++)); do BAR+="░"; done

# Context size label
[ "$CTX_SIZE" -ge 1000000 ] && CL="1M" || CL="200k"

# --- Duration (human-readable) ---
TOTAL_MINS=$((DURATION_MS / 60000))
if [ "$TOTAL_MINS" -ge 60 ]; then
    DUR_H=$((TOTAL_MINS / 60))
    DUR_M=$((TOTAL_MINS % 60))
    [ "$DUR_M" -gt 0 ] && DUR="${DUR_H}h${DUR_M}m" || DUR="${DUR_H}h"
elif [ "$TOTAL_MINS" -gt 0 ]; then
    DUR="${TOTAL_MINS}m"
else
    DUR=""
fi

# --- ccusage daily cost ---
CACHE="/tmp/.ccusage_today_cost"
DC=""
if [ -f "$CACHE" ]; then
    CD=$(head -1 "$CACHE" 2>/dev/null)
    if [ "$CD" = "$(date +%Y-%m-%d)" ]; then
        DC_RAW=$(tail -1 "$CACHE" 2>/dev/null)
        DC=$(printf "%.${COST_DECIMALS}f" "$DC_RAW")
    fi
fi

# ╭─────────────────── BUILD OUTPUT ───────────────────╮

O=""

# Model badge
O+="${DIM}╭${RST} ${CYN}${BOLD}${MODEL}${RST} ${DIM}╮${RST} "

# Context bar + percentage
O+="${CTX_COLOR}${BAR}${RST} ${CTX_COLOR}${CTX_PCT}%${RST}${DIM}/${CL}${RST}"

# Separator
O+=" ${DIM}◆${RST} "

# Cost
O+="${MAG}\$${COST}${RST}"
[ -n "$DC" ] && [ "$DC" != "0" ] && O+=" ${DIM}‹\$${DC}/d›${RST}"

# Duration
[ -n "$DUR" ] && O+=" ${DIM}◆${RST} ${WHT}${DUR}${RST}"

# Lines changed
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
    O+=" ${DIM}◆${RST} ${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"
fi

# Plan usage
if [ -n "$RATE_5H" ] || [ -n "$RATE_7D" ]; then
    O+=" ${DIM}│${RST}"

    # 5-hour window
    if [ -n "$RATE_5H" ]; then
        RI5=$(echo "$RATE_5H" | cut -d. -f1)
        R5C=$(color_by_pct "$RI5")
        O+=" ${DIM}5h${RST} ${R5C}${RI5}%${RST}"
        # Reset countdown when ≥50%
        if [ -n "$RATE_5H_RESET" ] && [ "$RATE_5H_RESET" != "null" ] && [ "$RI5" -ge 50 ]; then
            NOW=$(date +%s)
            LEFT=$(( (RATE_5H_RESET / 1000 - NOW) / 60 ))
            if [ "$LEFT" -gt 60 ]; then
                LH=$((LEFT / 60)); LM=$((LEFT % 60))
                O+=" ${DIM}⟳${LH}h${LM}m${RST}"
            elif [ "$LEFT" -gt 0 ]; then
                O+=" ${DIM}⟳${LEFT}m${RST}"
            fi
        fi
    fi

    # 7-day window
    if [ -n "$RATE_7D" ]; then
        RI7=$(echo "$RATE_7D" | cut -d. -f1)
        R7C=$(color_by_pct "$RI7")
        O+=" ${DIM}│ 7d${RST} ${R7C}${RI7}%${RST}"
    fi
fi

echo -e "$O"
