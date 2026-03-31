# claude-usage-monitor

Context window & cost monitoring plugin for Claude Code, with ccusage integration.

## Features

- **Status Line** — Real-time context window usage bar with color-coded warnings
- **Cost Tracking** — Session cost + daily total via ccusage
- **Rate Limits** — 5-hour rate limit display
- **Usage Skill** — `/claude-usage-monitor:usage` for detailed reports

## Status Line Preview

```
[Opus 4.6] ▓▓░░░ 42%/1M | $2.16($3.75/d) 30m +15-3 | 5h:12%
```

| Section | Description |
|---------|-------------|
| `[Opus 4.6]` | Current model |
| `▓▓░░░ 42%/1M` | Context window (green <60%, yellow 60-79%, red ≥80%) |
| `$2.16` | Session cost |
| `($3.75/d)` | Today's total (ccusage, updated every 30 min) |
| `30m` | Session duration |
| `+15-3` | Lines added/removed |
| `5h:12%` | 5-hour rate limit usage |

## Install

```bash
# Add marketplace
/plugin marketplace add 0xKatze/claude-usage-monitor

# Install
/plugin install claude-usage-monitor --scope user
```

Or test locally:
```bash
claude --plugin-dir ./claude-statusline-plugin
```

## Configuration

### Cost decimal places

Default is 4 decimal places. To change:

```bash
# Option 1: Config file
echo "COST_DECIMALS=2" > ~/.claude/usage-monitor.conf

# Option 2: Environment variable
export COST_DECIMALS=2
```

## Requirements

- `jq` — JSON parser (`sudo apt install jq`)
- `npx` — For ccusage (`npm install -g npx`)
- `cron` — For periodic ccusage cache updates (optional)
