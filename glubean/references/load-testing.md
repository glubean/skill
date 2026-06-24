# Load Testing

Glubean runs **load tests** — concurrent, sustained traffic against an API to
measure latency percentiles, throughput, and error rate under pressure — as a
first-class primitive alongside `test`, `contract`, and `workflow`. Load plans
live in `*.load.ts` files, run with `glubean load`, and upload as `kind=load`
runs that produce a rich **LoadArtifact** (per-endpoint/step breakdown, latency
distribution, timeline, threshold pass/fail, bounded failure samples).

This is distinct from `patterns/metrics.md` (which records single-request
metrics inside a functional test). Load testing is about **aggregate behaviour
under concurrency**.

## When to use it

Suggest a load test when the user asks about: performance under load, capacity,
throughput/RPS, p95/p99 latency, "can it handle N concurrent users", soak/stress
tests, or threshold-gating perf in CI. Do **not** auto-write load tests during
normal functional/contract coverage — load is opt-in (it generates real traffic).

## Define a load plan

A load plan = a **scenario** (the workload, reused across runs) + a **runner**
(concurrency, duration, thresholds). Import from `@glubean/sdk`:

```typescript
import { loadScenario, loadRunner, feeder } from "@glubean/sdk";
import { http } from "@glubean/sdk";

// 1. Scenario — the steps each virtual user repeats. Steps run in order;
//    each step's requests are attributed to its endpoint + step in the report.
const shopScenario = loadScenario<{ q: string }>("shop")
  .step("browse", async (ctx) => {
    const res = await http.get("load/catalog", { searchParams: { q: ctx.input.q } });
    ctx.expect(res.status).toBe(200);
  })
  .step("checkout", async (ctx) => {
    const res = await http.post("load/checkout", { json: { items: [{ sku: "A1", qty: 1 }] } });
    ctx.expect(res.status).toBe(201);
  });

// 2. Runner — concurrency + duration + thresholds. EXPORT it so the CLI finds it.
export const shopLoad = loadRunner("shop-load", {
  scenario: shopScenario,
  concurrency: 25,                 // virtual users in flight
  duration: "20s",                 // "60s" / "2m" / ms — total run length
  rampUp: "3s",                    // optional: ramp concurrency up over this window
  feeders: { term: feeder.fromArray([{ q: "pen" }, { q: "notebook" }], { key: "q" }).roundRobin() },
  input: ({ feed }) => ({ q: (feed.term as { q: string }).q }),  // per-iteration input
  thresholds: {
    transaction: { errorRate: "<5%", p95: "<400ms" },           // whole-scenario gate
    endpoints: {
      "GET /load/catalog":  { p95: "<120ms", p99: "<400ms", errorRate: "<0.5%" },
      "POST /load/checkout": { p95: "<180ms", errorRate: "<4%" },
    },
  },
  report: { failureTraces: 10, slowTransactionSummaries: 10 },   // bounded sample caps
});
```

## LoadContext (`ctx` in a load step)

Load steps get a **LoadContext**, not the full TestContext. Kept: `http`, `vars`,
`secrets`, `session`, `expect`, `assert`, `skip`, `fail`, `log`, `warn`,
`pollUntil`, `setTimeout`. Added for load: `input` (per-iteration input from
feeders), `iteration` (`{ id, index }`), `producerSlot` (`{ id, index }`),
`now()`, `report` (checkpoint / primaryComplete).

**Removed** (don't fit concurrent load): `validate`, `trace`, `metric`,
`action`, `event`, `getMemoryUsage`, `retryCount`. So do NOT call `ctx.metric()`
inside a load step — use a functional test for that.

## Config keys

| Key | Meaning |
|-----|---------|
| `concurrency` | Virtual users in flight |
| `duration` | Total run length (`"60s"`, `"2m"`, or ms) |
| `iterations` | Alternative to duration: fixed iteration count |
| `rampUp` | Ramp concurrency up over this window |
| `feeders` | Data providers (`feeder.fromArray/fromCsv/...`, `.roundRobin()` / `.random()`) |
| `input` | `({ feed, iteration, producerSlot }) => sceneInput` per iteration |
| `pacing.thinkTime` | Delay between steps (`"100ms"` or a distribution) |
| `thresholds` | Pass/fail gates (see below) |
| `report` | Bounded sample caps: `failureTraces`, `slowTransactionSummaries` |
| `assertions.onFailure` | `"continue"` \| `"skipRemainingSteps"` \| `"abortIteration"` |
| `abort` | `"precise"` (default) \| `"coarse"` — how a run abort reaches in-flight requests |

### Thresholds — the pass/fail gate

Thresholds turn a load run green/red (and gate CI). Scopes:

```typescript
thresholds: {
  transaction: { errorRate: "<1%", p95: "<2000ms", p99: "<4000ms", throughputPerSec: ">500" },
  endpoints: { "GET /api/foo": { p95: "<200ms", errorRate: "<0.5%" } },
  steps:     { "checkout":    { p95: "<800ms" } },
}
```

Expressions are comparison strings: `"<400ms"`, `"<5%"`, `">500"`. Each evaluated
threshold lands in the artifact's `summary.thresholds[]` with `actual` + `pass`.

## Traffic mix & table expansion

Multiple weighted scenarios in one run:

```typescript
export const mixedLoad = loadRunner("mixed", {
  scenarios: [
    loadMixEntry({ id: "checkout", scenario: checkoutScenario, weight: 70 }),
    loadMixEntry({ id: "refund",   scenario: refundScenario,   weight: 30 }),
  ],
  concurrency: 300,
  duration: "60s",
});
```

One plan per data row (e.g. per region):

```typescript
export const regionLoad = loadRunner.each(REGIONS)("region-{region}", (row) => ({
  scenario: scenarioForRegion(row.region),
  concurrency: 100,
  duration: "30s",
}));
```

## Run & upload

```bash
glubean load tests/load/shop.load.ts     # Run one plan locally
glubean load                             # Run the load suite/profile from glubean.yaml
glubean load --upload                     # Run + upload (kind=load) to a target
glubean load --upload --target tgt_abc    # Upload to a specific target
```

In `glubean.yaml`, mark a suite as load by listing `load` in its `kinds`:

```yaml
suites:
  load:
    target: ./tests/load
    kinds: [load]
profiles:
  perf:
    suites: [load]
    upload: { enabled: true, targetId: tgt_abc, tokenEnv: GLUBEAN_TOKEN }
```

See [cli-reference.md](cli-reference.md) for auth/upload details and
[ci-workflow.md](ci-workflow.md) for gating perf in CI.

## What a load run produces (LoadArtifact)

`schemaVersion: "glubean.load.v1"`. Key fields the Cloud dashboard renders:

- `summary` — `pass` (threshold verdict), `totalIterations`,
  `successfulIterations`, `failedIterations`, `errorRate`, `throughputPerSec`,
  `latency` (`{ p50, p90, p95, p99, max }` ms), `latencyDistribution[]`
  (fixed-ladder histogram), `thresholds[]` (each `{ scope, metric, expression,
  actual, pass }`), `advisories[]`.
- `endpoints[]` — per route (`routeKey`, `method`): `requestCount`, `errorRate`,
  `latency`, `throughputPerSec`, `latencyDistribution`, `statusCounts`.
- `steps[]` — per scenario step: `invocationCount`, `errorRate`, `latency`.
- `scenarios[]` — per scenario aggregate.
- `matrix[]` — scenario-step × endpoint (which endpoint each step hit).
- `timeline` — fixed-width windows over the run: `{ offsetMs, requests, errors,
  throughputPerSec, latency, iterations, peakInFlight }`.
- `samples` — bounded `failureTraces[]` (failed iterations) +
  `slowTransactions[]` (slow-but-passing), capped by `report`.

On the Cloud dashboard these surface in the target's **Performance** tab
(load-run table + run-vs-run comparison) and the **Runs** tab (per-run detail:
config, KPI cards, over-time timeline, latency histogram, per-endpoint table,
transaction breakdown, threshold table, samples).

## Agent behavior

- **Opt-in only.** Never author load tests as part of routine coverage — they
  generate real concurrent traffic. Write one when the user asks about
  performance / capacity / throughput / latency-under-load.
- **Start small.** Default to modest `concurrency` + short `duration` (e.g. 25 /
  "20s") and let the user scale up — don't open with 1000 VUs.
- **Always set thresholds** so the run has a pass/fail verdict and can gate CI;
  base them on the user's SLOs, or propose conservative ones and ask.
- **Reuse functional knowledge.** A load scenario is the same `http` calls as a
  functional test, just without per-request assertions beyond status/shape.
- **Don't use `ctx.metric()` in load steps** (not available) — for custom
  business metrics use a functional test ([patterns/metrics.md](patterns/metrics.md)).
- Point the user at the **Performance** tab after `--upload` to see the run and
  compare against a baseline run.
