# Custom Metrics

Record performance measurements visible in Cloud dashboard.

## Why this pattern

**Problem:** you want to track API response time or payload size, but `console.time()` only prints to stdout — it is invisible to MCP, CI reporters, and Cloud analytics.
**Alternative:** use `console.log` with timestamps — but the output is unstructured text that agents cannot parse and Cloud cannot graph.
**This pattern:** `ctx.metric()` records named measurements that appear in traces, MCP results, and Cloud dashboards with filtering by tags. You can alert on regressions and track trends across runs — not just print a number once.

```typescript
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";

export const responseTime = test(
  { id: "response-time", name: "API response time under threshold", tags: ["perf"] },
  async ({ expect, metric }) => {
    const start = performance.now();
    await api.get("projects").json();
    const duration = performance.now() - start;

    metric("api.projects.list", duration, {
      unit: "ms",
      tags: { endpoint: "/projects" },
    });
    expect(duration).toBeLessThan(2000);
  },
);
```

## Key points

- `ctx.metric(name, value, { unit?, tags? })` — records a named metric
- Metrics appear in Cloud analytics with tags for filtering
- Common units: `"ms"`, `"bytes"`, `"count"`
