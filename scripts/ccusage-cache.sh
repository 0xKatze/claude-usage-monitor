#!/bin/bash
# Updates ccusage daily cost cache (runs every 30 min via cron)
CACHE="/tmp/.ccusage_today_cost"
TODAY=$(date +%Y-%m-%d)
TODAY_SHORT=$(date +%m-%d)

COST=$(npx -y ccusage@latest --display daily 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | grep -B1 "$TODAY_SHORT" \
    | head -1 \
    | grep -oP '\$[\d.]+' \
    | tr -d '$')

[ -n "$COST" ] && { echo "$TODAY" > "$CACHE"; echo "$COST" >> "$CACHE"; }
