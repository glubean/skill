# Polling / Async Verification

Wait for async jobs, eventual consistency, delayed state changes, or inbound deliveries.

## Choose the right API

| Situation | Use |
|---|---|
| Imperative `test()` builder step, result updates test state | `test().poll()` |
| Lifecycle promise composed from contract cases | `workflow().poll()` |
| Quick-mode test, no stateful poll step needed | `ctx.pollUntil()` |

Prefer first-class poll nodes (`test().poll()` or `workflow().poll()`) when the polling itself is meaningful evidence. Use `ctx.pollUntil()` for small quick-mode checks.

## `test().poll()`

Use builder `.poll()` when an async operation belongs inside an imperative test and the satisfying response should update builder state.

```typescript
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";

export const asyncJob = test("async-job")
  .meta({ name: "Wait for async job to complete", tags: ["api"] })
  .step("start job", async () => {
    const { jobId } = await api
      .post("jobs", { json: { type: "report" } })
      .json<{ jobId: string }>();

    return { jobId };
  })
  .poll(
    "wait for job completion",
    async (_ctx, state) => api.get(`jobs/${state.jobId}`).json<{ status: string; resultUrl?: string }>(),
    {
      timeout: 30000,
      every: 2000,
      until: (_ctx, job) => job.status === "completed",
      out: (state, job) => ({ ...state, resultUrl: job.resultUrl }),
    },
  )
  .step("verify result URL", async (ctx, state) => {
    ctx.assert(!!state.resultUrl, "Completed async job exposes a result URL", {
      actual: state.resultUrl,
      expected: "non-empty resultUrl",
    });
  });
```

## `workflow().poll()`

Use workflow polling when the async lifecycle is part of the product contract.

```typescript
import { workflow } from "@glubean/sdk";

export const exportLifecycle = workflow("export-lifecycle")
  .call("start-export", startExport.case("success"), {
    out: (_s, res) => ({ exportId: res.body.id as string }),
  })
  .poll("wait-for-export", getExport.case("ready"), {
    in: (s) => ({ params: { id: s.exportId } }),
    timeout: 60000,
    every: 2000,
    until: (w) => w.when((res: { body: { status: string } }) => res.body.status).eq("ready"),
    out: (s, res) => ({ ...s, downloadUrl: res.body.downloadUrl as string }),
  });
```

For inbound contract cases, `poll()` waits for the counterparty to call your receiver:

```typescript
.poll("wait-for-webhook", paymentWebhook.case("created"), {
  via: (s) => s.receiver,
  correlate: {
    event: (event) => event.data.object.metadata.orderId,
    state: (s) => s.orderId,
  },
  timeout: 60000,
})
```

## `ctx.pollUntil()`

Use `ctx.pollUntil()` in quick-mode tests when you only need a wait loop.

```typescript
export const asyncJobQuick = test("async-job-quick", async (ctx) => {
  const { jobId } = await api.post("jobs", { json: { type: "report" } }).json<{ jobId: string }>();

  await ctx.pollUntil({ timeoutMs: 30000, intervalMs: 2000 }, async () => {
    const job = await api.get(`jobs/${jobId}`).json<{ status: string }>();
    ctx.log("Job status", { status: job.status });
    return job.status === "completed";
  });

  const result = await api.get(`jobs/${jobId}`).json<{ status: string }>();
  ctx.expect(result.status).toBe("completed");
});
```

## Rules

- Do not use fixed sleeps for eventual consistency.
- Always set finite bounds. For builder/workflow poll, use `timeout`, or use `maxAttempts` with `perAttemptTimeout`.
- Use `workflow().poll()` only with existing contract cases. If no contract case exists yet, write the contract first or use `pollAction()` as a temporary bridge.
- Use diagnostic names: `"wait for export to become ready"` is better than `"poll"`.
- When the final result matters to later steps, capture it with `out`.
