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

## Header-based metrics

Many APIs return useful performance data in response headers (e.g. `x-processing-duration`, `server-timing`, `x-ratelimit-remaining`). These make excellent metrics:

```typescript
export const serverTiming = test(
  { id: "server-timing", tags: ["perf"] },
  async ({ expect, metric }) => {
    const res = await api.get("projects");
    const serverDuration = res.headers.get("x-processing-duration");
    if (serverDuration) {
      metric("api.projects.server-duration", Number(serverDuration), {
        unit: "ms",
        tags: { endpoint: "/projects" },
      });
    }
    expect(res.status).toBe(200);
  },
);
```

**Agent behavior:** when setting up performance metrics, ask the user: "Does your API return timing or rate limit data in response headers?" Most users don't think to mention this. Test code always has full access to `res.headers`.

Note: MCP traces strip most headers by default — the agent cannot discover these headers through traces alone. If the user wants header data visible in traces, see [mcp.md — Trace header filtering](../mcp.md) for how to configure `keepResponseHeaders`.

## Key points

- `ctx.metric(name, value, { unit?, tags? })` — records a named metric
- Metrics appear in Cloud analytics with tags for filtering
- Common units: `"ms"`, `"bytes"`, `"count"`
