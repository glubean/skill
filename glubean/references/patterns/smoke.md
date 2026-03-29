# Smoke Test

Simplest test — hit one endpoint, check it responds correctly.

## Why this pattern

**Problem:** you don't know if the API is reachable, auth works, or the base URL is correct — jumping straight to CRUD or schema tests means debugging infra issues mixed with logic failures.
**Alternative:** write a full CRUD test first — but if the API is down or auth is misconfigured, every step fails and the root cause is buried.
**This pattern:** a smoke test is the cheapest possible verification. If it passes, you know the connection, auth, and basic response shape work. Write this first, then build on it.

```typescript
// tests/api/health.test.ts
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";

export const healthCheck = test(
  { id: "health-check", name: "Health endpoint returns 200", tags: ["smoke"] },
  async ({ expect }) => {
    const res = await api.get("health").json<{ status: string }>();
    expect(res.status).toBe("ok");
  },
);
```

## Exploring multiple endpoints

When exploring several endpoints in the same domain, write one export per endpoint in a single file.
Do NOT use data-driven patterns to loop over different endpoints.

```typescript
// explore/billing.test.ts
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";

export const invoicesChart = test(
  { id: "billing-invoices-chart", tags: ["explore", "billing"] },
  async ({ expect }) => {
    const res = await api.post("billing.invoices-chart.get").json<{ data: unknown[] }>();
    expect(res.data).toBeDefined();
  },
);

export const cardsList = test(
  { id: "billing-cards-list", tags: ["explore", "billing"] },
  async ({ expect }) => {
    const res = await api.post("billing.cards.list").json<{ items: unknown[] }>();
    expect(res.items).toBeDefined();
  },
);
```

## Smoke with multiple checks

```typescript
export const getProduct = test(
  { id: "get-product", name: "GET single product", tags: ["smoke", "api"] },
  async ({ expect, log }) => {
    const product = await api.get("products/1").json<{
      id: number;
      title: string;
      price: number;
    }>();

    expect(product.id).toBe(1);
    expect(product.title).toBeDefined();
    expect(product.price).toBeGreaterThan(0);
    log(`${product.title} — $${product.price}`);
  },
);
```
