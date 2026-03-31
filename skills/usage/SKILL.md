---
name: usage
description: Show detailed Claude Code token usage and cost report via ccusage
---

Run the ccusage CLI tool to display a detailed usage report. Execute:

```bash
npx -y ccusage@latest --display daily
```

Present the results to the user in a clean, readable format. Include:
1. Daily token breakdown (input, output, cache)
2. Daily cost in USD
3. Total accumulated cost
4. Which models were used each day

If the user asks for a specific time range, use the appropriate ccusage flags.
