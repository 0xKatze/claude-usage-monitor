#!/bin/bash
# Claude Code Custom Status Line — claude-usage-monitor plugin
# Opus4.6 ██▋░░░░ 37% ◆ $9.89‹$3.75› 23h33m +457-28 │ 5h15% 7d1%
#
# Config: ~/.claude/usage-monitor.conf
#   COST_DECIMALS=2  BAR_WIDTH=7

input=$(cat)

# --- Config ---
CONF="$HOME/.claude/usage-monitor.conf"
[ -f "$CONF" ] && source "$CONF"
COST_DECIMALS="${COST_DECIMALS:-${CLAUDE_PLUGIN_OPTION_cost_decimals:-2}}"
BAR_WIDTH="${BAR_WIDTH:-7}"

# --- Parse JSON ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"' | sed 's/Claude //;s/ (.*//;s/ /-/')
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
GRN='\033[32m'; YLW='\033[33m'; RED='\033[31m'; CYN='\033[36m'; MAG='\033[35m'

cpct() { [ "$1" -ge 80 ] && echo "${BOLD}${RED}" || { [ "$1" -ge 60 ] && echo "${YLW}" || echo "${GRN}"; }; }

# --- Context bar ---
BLOCKS=("░" "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")
FF=$(( CTX_PCT * BAR_WIDTH / 100 ))
RR=$(( (CTX_PCT * BAR_WIDTH * 8 / 100) % 8 ))
EF=$(( BAR_WIDTH - FF - (RR > 0 ? 1 : 0) ))
CC=$(cpct "$CTX_PCT")
BAR=""; for ((i=0;i<FF;i++)); do BAR+="█"; done
[ "$RR" -gt 0 ] && BAR+="${BLOCKS[$RR]}"
for ((i=0;i<EF;i++)); do BAR+="░"; done

# --- Duration ---
TM=$((DURATION_MS / 60000))
if [ "$TM" -ge 60 ]; then
    H=$((TM/60)); M=$((TM%60))
    [ "$M" -gt 0 ] && DUR="${H}h${M}m" || DUR="${H}h"
elif [ "$TM" -gt 0 ]; then DUR="${TM}m"
else DUR=""; fi

# --- ccusage daily cost ---
CACHE="/tmp/.ccusage_today_cost"; DC=""
if [ -f "$CACHE" ]; then
    [ "$(head -1 "$CACHE")" = "$(date +%Y-%m-%d)" ] && DC=$(printf "%.${COST_DECIMALS}f" "$(tail -1 "$CACHE")")
fi

# --- Context size label ---
[ "$CTX_SIZE" -ge 1000000 ] && CL="1M" || CL="200k"

# --- Build ---
O="${CYN}${MODEL}${RST} "
O+="${CC}${BAR}${RST} ${CC}${CTX_PCT}%${RST}${DIM}/${CL}${RST}"
O+=" ${DIM}◆${RST} ${MAG}\$${COST}${RST}"
[ -n "$DC" ] && [ "$DC" != "0" ] && O+="${DIM}‹\$${DC}/d›${RST}"
[ -n "$DUR" ] && O+=" ${DUR}"
([ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]) && O+=" ${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"

if [ -n "$RATE_5H" ] || [ -n "$RATE_7D" ]; then
    O+=" ${DIM}│${RST}"
    if [ -n "$RATE_5H" ]; then
        RI5=$(echo "$RATE_5H" | cut -d. -f1); R5C=$(cpct "$RI5")
        O+=" ${DIM}5h${RST} ${R5C}${RI5}%${RST}"
        if [ -n "$RATE_5H_RESET" ] && [ "$RATE_5H_RESET" != "null" ] && [ "$RI5" -ge 50 ]; then
            LEFT=$(( (RATE_5H_RESET / 1000 - $(date +%s)) / 60 ))
            [ "$LEFT" -gt 0 ] && O+="${DIM}⟳${LEFT}m${RST}"
        fi
    fi
    [ -n "$RATE_7D" ] && { RI7=$(echo "$RATE_7D" | cut -d. -f1); O+=" ${DIM}7d${RST} $(cpct "$RI7")${RI7}%${RST}"; }
fi

echo -e "$O"
