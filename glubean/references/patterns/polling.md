# Polling / Async Verification

Wait for async jobs, eventual consistency, or delayed state changes.

## Why this pattern

**Problem:** async APIs return 202/queued immediately — asserting the final state without waiting gives false failures; adding a fixed `sleep()` is fragile and slow.
**Alternative:** `while` loop with `setTimeout` — but you have no timeout protection (hangs forever), no structured logging per attempt, and no integration with test reporting.
**This pattern:** `pollUntil` retries with a configurable interval, enforces a hard timeout, and each poll attempt is visible in traces. The test reads as intent ("wait until completed") not mechanism ("loop and sleep").

```typescript
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";

export const asyncJob = test(
  { id: "async-job", name: "Wait for async job to complete", tags: ["api"] },
  async ({ expect, pollUntil, log }) => {
    const { jobId } = await api
      .post("jobs", { json: { type: "report" } })
      .json<{ jobId: string }>();

    await pollUntil({ timeoutMs: 30000, intervalMs: 2000 }, async () => {
      const job = await api.get(`jobs/${jobId}`).json<{ status: string }>();
      log(`Job status: ${job.status}`);
      return job.status === "completed";
    });

    const result = await api.get(`jobs/${jobId}`).json<{ status: string }>();
    expect(result.status).toBe("completed");
  },
);
```

## Key points

- `pollUntil` retries until the function returns truthy or timeout
- Default `intervalMs` is 1000ms if not specified
- Use `log()` inside the poll to track progress in reports
