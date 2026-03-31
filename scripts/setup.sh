#!/bin/bash
# Plugin setup — installs statusline + ccusage cron
set -e

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
DEST="$HOME/.claude"

# Install statusline script
cp "$PLUGIN_DIR/scripts/statusline.sh" "$DEST/statusline.sh"
chmod +x "$DEST/statusline.sh"

# Install ccusage cache script
cp "$PLUGIN_DIR/scripts/ccusage-cache.sh" "$DEST/ccusage-cache.sh"
chmod +x "$DEST/ccusage-cache.sh"

# Add ccusage cron if not present
if command -v crontab &>/dev/null; then
    (crontab -l 2>/dev/null | grep -v 'ccusage-cache' ; echo "*/30 * * * * $DEST/ccusage-cache.sh > /dev/null 2>&1") | crontab -
fi

# Check jq
if ! command -v jq &>/dev/null; then
    echo "WARNING: jq is required. Install with: sudo apt install jq"
fi

# Initial ccusage cache
bash "$DEST/ccusage-cache.sh" &>/dev/null &

echo "claude-usage-monitor installed."
echo ""
echo "Add to ~/.claude/settings.json:"
echo '  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }'
