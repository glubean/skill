# Data-Driven Tests

## When NOT to use data-driven

Data-driven is for testing **the same endpoint** with varying input parameters.
If your cases hit **different endpoints**, write a separate `export const` for each — do not
put different endpoints into a data file and loop over them with `test.each`/`test.pick`.

**Anti-pattern** — different endpoints crammed into one test:
```typescript
// ❌ WRONG: each case is a different endpoint
const cases = await fromDir.merge("data/billing/");
export const billing = test.pick(cases)(
  { id: "billing-$_pick", tags: ["explore"] },
  async ({ expect }, { endpoint, body }) => {
    const res = await api.post(endpoint, { json: body }).json<Record<string, unknown>>();
    expect(res).toBeDefined();
  },
);
```

**Correct** — separate export per endpoint, data-driven only for parameter variations:
```typescript
// ✅ RIGHT: each endpoint is its own test
export const invoicesChart = test(
  { id: "billing-invoices-chart", tags: ["explore", "billing"] },
  async ({ expect }) => {
    const res = await api.post("billing.invoices-chart.get").json<{ data: unknown[] }>();
    expect(res.data).toBeDefined();
  },
);

export const invoicesList = test(
  { id: "billing-invoices-list", tags: ["explore", "billing"] },
  async ({ expect }) => {
    const res = await api.post("billing.invoices.list").json<{ items: unknown[] }>();
    expect(res.items).toBeDefined();
  },
);

// ✅ Data-driven: same endpoint, different search params
export const invoiceSearch = test.each([
  { q: "paid", minResults: 1 },
  { q: "overdue", minResults: 0 },
])("invoice-search-$q", async ({ expect }, { q, minResults }) => {
  const res = await api.post("billing.invoices.list", { json: { q } }).json<{ total: number }>();
  expect(res.total).toBeGreaterThanOrEqual(minResults);
});
```

## Which one to use?

| | `test.each` | `test.pick` |
|---|---|---|
| **Runs** | **All** cases | **One selected** case |
| **Use case** | Regression, coverage | Explore, debug, ad-hoc |
| **Data source** | Array: `fromYaml`, `fromJson`, `fromCsv`, `fromDir` | Object map: `fromYaml.map`, `fromJson.map`, `fromDir.merge` |
| **Filter** | `--filter` by test id | `--pick` to select by key |

**Rule of thumb:** need to run every case → `.each`. Need to pick one and iterate → `.pick`.

## test.each — runs ALL cases

Each JSON file in the directory becomes a separate test.

```
data/users/
  alice.json    → { "username": "alice", "expectedStatus": 200 }
  bob.json      → { "username": "bob", "expectedStatus": 200 }
  unknown.json  → { "username": "no-one", "expectedStatus": 404 }
```

```typescript
import { test, fromDir } from "@glubean/sdk";
import type { UserCase } from "../../types/users.ts";
import { api } from "../../config/api.ts";

const users = await fromDir<UserCase>("data/users/");

// Quick mode — string ID
export const userLookup = test.each(users)(
  "user-lookup-$username",              // $field interpolates from row
  async ({ expect }, { username, expectedStatus }) => {
    const res = await api.get(`users/${username}`);
    expect(res).toHaveStatus(expectedStatus);
  },
);

// Quick mode — TestMeta object (with tags)
export const userLookupTagged = test.each(users)(
  { id: "user-lookup-$username", tags: ["smoke", "api"] },
  async ({ expect }, { username, expectedStatus }) => {
    const res = await api.get(`users/${username}`);
    expect(res).toHaveStatus(expectedStatus);
  },
);

// Builder mode (omit callback)
export const userFlow = test.each(users)("user-flow-$username")
  .step("fetch", async (ctx, _state, row) => {
    const res = await ctx.http.get(`/users/${row.username}`).json<{ id: string }>();
    return { id: res.id };
  })
  .step("verify", async (ctx, state) => {
    ctx.expect(state.id).toBeDefined();
  });
```

## test.pick — runs ONE selected case

`shared.json` has defaults. `*.local.json` for personal overrides (gitignored).

```
data/search/
  shared.json       → { "basic": { "q": "test", "min": 1 }, "empty": { "q": "xyznotfound", "min": 0 } }
  mine.local.json   → { "basic": { "q": "my-custom-query", "min": 5 } }
```

```typescript
import { test, fromDir } from "@glubean/sdk";
import type { SearchQuery } from "../../types/search.ts";
import { api } from "../../config/api.ts";

const queries = await fromDir.merge<SearchQuery>("data/search/");

// String ID
export const searchTests = test.pick(queries)(
  "search-$_pick",                      // $_pick = case name
  async ({ expect }, { q, min }) => {
    const res = await api
      .get("products/search", { searchParams: { q } })
      .json<{ total: number }>();
    expect(res.total).toBeGreaterThanOrEqual(min);
  },
);

// TestMeta object (with tags)
export const searchTagged = test.pick(queries)(
  { id: "search-$_pick", name: "Search: $_pick", tags: ["api"] },
  async ({ expect }, { q, min }) => {
    const res = await api
      .get("products/search", { searchParams: { q } })
      .json<{ total: number }>();
    expect(res.total).toBeGreaterThanOrEqual(min);
  },
);
```

## Inline data (no files needed)

```typescript
// test.each — string ID
test.each([
  { id: 1, expected: 200 },
  { id: 999, expected: 404 },
])("get-user-$id", async (ctx, { id, expected }) => { ... });

// test.each — TestMeta object (with tags)
test.each([
  { id: 1, expected: 200 },
  { id: 999, expected: 404 },
])({ id: "get-user-$id", tags: ["smoke"] }, async (ctx, { id, expected }) => { ... });

// test.pick — string ID
test.pick({
  "normal":    { name: "Alice", age: 25 },
  "edge-case": { name: "", age: -1 },
})("create-user-$_pick", async (ctx, data) => { ... });

// test.pick — TestMeta object (with tags)
test.pick({
  "normal":    { name: "Alice", age: 25 },
  "edge-case": { name: "", age: -1 },
})({ id: "create-user-$_pick", tags: ["api"] }, async (ctx, data) => { ... });
```

## Advanced: Structured Test Data

For complex scenarios, flat key-value pairs are not enough. Use a YAML file where each case has nested `request` and `expect` blocks — data drives both the input **and** the assertions.

### YAML data file

```yaml
# data/search-queries.yaml
# Each top-level key is a test case name.
# Structure is arbitrary — not limited to flat key-value.

# Search by product name — basic keyword search
by-name:
  description: Search by product name          # human-readable label for logs
  request:                                      # drives the HTTP request
    q: phone
  expect:                                       # drives assertions
    minResults: 1

# Search by category — broader search
by-category:
  description: Search products by category keyword
  request:
    q: laptops
  expect:
    minResults: 1

# Edge case — empty query
empty-query:
  description: Empty query returns nothing
  request:
    q: ""
  expect:
    minResults: 0
```

### TypeScript test file

```typescript
import { fromYaml, test } from "@glubean/sdk";
import type { SearchQueryCase } from "../../types/search.ts";

const cases = await fromYaml.map<SearchQueryCase>("data/search-queries.yaml");

export const search = test.pick(cases)(
  { id: "search-$_pick", tags: ["api"] },
  async (ctx, { description, request, expect: exp }) => {
    ctx.log(description);

    const result = await ctx.http
      .get("https://dummyjson.com/products/search", {
        searchParams: { q: request.q },
      })
      .json<{ total: number }>();

    ctx.expect(result.total).toBeGreaterThanOrEqual(exp.minResults);
  },
);
```

### Key takeaways

1. **`description` in data** — each case carries a human-readable label so logs and results are easy to scan without reading the YAML.
2. **`request` + `expect` separation** — data simultaneously drives both the input (what to send) and the assertions (what to check). One file, two purposes.
3. **Arbitrary structure** — YAML cases are not limited to flat key-value. Nest as deep as needed (`request.headers`, `expect.schema`, etc.).

## Other data loaders

```typescript
// Array loaders — for test.each
const rows = await fromCsv<Row>("data/file.csv");
const rows = await fromYaml<Row>("data/file.yaml");
const rows = await fromJson<Row>("data/file.json");
const rows = await fromJsonl<Row>("data/file.jsonl");
const items = await fromDir.concat<Item>("data/items/");

// Map loaders — for test.pick
const cases = await fromYaml.map<Case>("data/scenarios.yaml");
const cases = await fromJson.map<Case>("data/scenarios.json");
const cases = await fromDir.merge<Case>("data/scenarios/");
```

## Data loader rules

These rules apply to ALL data loading in Glubean tests. Follow them strictly.

1. **Always use SDK loaders (`fromJson`, `fromCsv`, `fromYaml`, etc.)** — never use `import data from "./file.json" with { type: "json" }`. Native import has limited path resolution and inconsistent behavior across runtimes.

2. **Always load data into an independent `const`** — never inline `await` inside `test.each()`.

```typescript
// ✅ CORRECT: independent const
const users = await fromJson<User>("data/users.json");
export const tests = test.each(users)(...);

// ❌ WRONG: inline await — if this fails, ALL exports in the file are blocked
export const tests = test.each(await fromJson<User>("data/users.json"))(...);
```

3. **Always provide a type generic** — use `type` (not `interface`) for data row types. Data loaders require index signatures.

4. **Keep types in `types/`** — do not declare data types inside test files. Types in `types/` are reusable across `explore/`, `contracts/`, and `tests/`.

```typescript
// types/users.ts
export type UserCase = {
  username: string;
  expectedStatus: number;
};

// tests/users.test.ts
import type { UserCase } from "../types/users.ts";
const users = await fromDir<UserCase>("data/users/");
```

5. **Use bare paths for shared data, relative paths for colocated data.**

| Path format | Resolves from |
|-------------|---------------|
| `data/users.json` (bare) | Project root (where `package.json` lives) |
| `./local/data.json` | Calling file's directory |
| `../shared/data.json` | Calling file's parent directory |
