# Glubean SDK Reference

Quick reference for `@glubean/sdk` and `@glubean/browser`. For full type details, check the source via go-to-definition.

## Imports

```typescript
import { test, configure, definePlugin, defineSession, fromDir, fromCsv, fromJson, fromYaml, fromJsonl } from "@glubean/sdk";
import { browser } from "@glubean/browser";
import type { InstrumentedPage } from "@glubean/browser";
```

---

## test()

```typescript
// Quick mode
test(id: string | TestMeta, fn: (ctx: TestContext) => Promise<void>): Test

// Builder mode (multi-step)
test(id: string | TestMeta): TestBuilder

// Modifiers
test.only(...)   // Run only this test
test.skip(...)   // Skip this test
```

### TestMeta

```typescript
{
  id: string                    // Unique kebab-case ID
  name?: string                 // Human-readable name
  tags?: string | string[]      // e.g. ["smoke", "api"]
  timeout?: number              // Default 30000ms
}
```

### TestBuilder (multi-step)

```typescript
test("my-test")
  .meta({ name: "...", tags: ["api"] })
  .setup(async (ctx) => {
    return { token: "..." };         // State passed to steps
  })
  .step("step-name", async (ctx, state) => {
    // Use state from setup or previous step
    return { ...state, newData };     // Return new state (optional)
  })
  .teardown(async (ctx, state) => {
    // Always runs, even on failure — use for cleanup
  });
```

### test.each (one file = one case)

```typescript
const data = await fromDir<{ username: string }>("data/users/");

export const tests = test.each(data)(
  "user-$username",                   // $field interpolates from row
  async (ctx, row) => { ... },
);
```

### test.pick (named cases, merged files)

```typescript
const cases = await fromDir.merge<{ q: string }>("data/search/");

export const tests = test.pick(cases)(
  "search-$_pick",                    // $_pick = case name
  async (ctx, row) => { ... },
);
```

### test.extend (fixtures)

```typescript
import { test, type ExtensionFn } from "@glubean/sdk";

const pageFixture: ExtensionFn<Page> = async (ctx, use) => {
  const pg = await createPage();
  try { await use(pg); }
  finally { await pg.close(); }
};

const myTest = test.extend({ page: pageFixture });

export const t = myTest({ id: "..." }, async ({ page }) => {
  // page is available here
});
```

---

## TestContext

Every test function receives `ctx` with:

```typescript
ctx.http                              // Pre-configured HTTP client
ctx.expect(value)                     // Soft assertion (returns Expectation)
ctx.assert(condition, message?, details?)  // Hard assertion ({ actual, expected })
ctx.warn(condition, message)          // Warning (non-failing)
ctx.log(message, data?)              // Structured log
ctx.vars.require("KEY")              // Read env var (throws if missing)
ctx.secrets.require("KEY")           // Read secret (auto-redacted)
ctx.trace({ method, url, status, duration, ... })  // Record API trace
ctx.metric("name", value, { unit?, tags? })        // Record metric
ctx.validate(data, zodSchema, label?) // Schema validation
ctx.skip(reason?)                     // Skip test
ctx.fail(message)                     // Fail test immediately
ctx.pollUntil({ timeoutMs, intervalMs? }, fn)      // Poll until fn returns truthy
ctx.setTimeout(ms)                    // Override timeout
```

> **Not available in quick mode:** `setup()`, `step()`, `teardown()` are builder-mode-only APIs.
> If your test needs cleanup, use builder mode — see `patterns/crud.md`.

---

## HTTP Client

From `configure()` or `ctx.http`. Auto-traces requests.

```typescript
http.get(url, options?).json<T>()
http.post(url, options?).json<T>()
http.put(url, options?).json<T>()
http.patch(url, options?).json<T>()
http.delete(url, options?).json<T>()

// Also: .text(), .blob(), .arrayBuffer()
```

### Response typing

For real projects, keep API response types in a dedicated `types/` directory and import them into tests. Do not define response types inline in test files unless you are writing a tiny scratch demo.

Prefer importing shared types over inline:

```typescript
// types/directions.ts
export interface DirectionsResponse {
  status: string;
  routes: { geometry: string; distance: number }[];
}

// ✅ Shared type — reusable, stays in sync
import type { DirectionsResponse } from "../types/directions.ts";
const res = await api.get("directions/json").json<DirectionsResponse>();

// ❌ Inline type — duplicated across tests, drifts over time
const res = await api.get("directions/json")
  .json<{ status: string; routes: { geometry: string; distance: number }[] }>();
```

If `types/` does not exist yet, create it before adding more typed tests.

### Schema organization

For real projects, keep reusable Zod schemas in a dedicated `schemas/` directory and import them into tests. Do not define reusable Zod schemas inline in test files unless you are writing a tiny scratch demo.

```typescript
// schemas/directions.ts
import { z } from "zod";

export const DirectionsSchema = z.object({
  status: z.string(),
  routes: z.array(
    z.object({
      geometry: z.string(),
      distance: z.number(),
    }),
  ),
});

// tests/maps/directions.test.ts
import { DirectionsSchema } from "../schemas/directions.ts";

const data = await api.get("directions/json").json();
ctx.validate(data, DirectionsSchema, "Directions response");
```

If `schemas/` does not exist yet, create it before adding more Zod-schema-based tests.

### Options

```typescript
{
  json: { ... },                       // JSON body (auto-serialized)
  body: formData | string,             // Raw body
  searchParams: { key: "value" },      // Query string
  headers: { "X-Custom": "value" },    // Headers
  timeout: 5000,                       // ms (default 10000, false = no timeout)
  retry: 3,                            // Retry count (or { limit, statusCodes, methods })
  throwHttpErrors: false,               // Throw on 4xx/5xx (default false)
  schema: {                             // Per-call Zod validation (any safeParse/parse schema)
    request: BodySchema,                // validates options.json before sending
    response: ResponseSchema,           // validates parsed body on .json()
    query: QuerySchema,                 // validates options.searchParams
    requestHeaders: HeadersSchema,      // validates per-call options.headers
    responseHeaders: HeadersSchema,     // validates final response headers
    // any field also accepts { schema, severity: "error" | "warn" | "fatal" }
  },
}
```

Use `schema:` for inline per-call validation. For file-level endpoint specs covering every case, use `contract.http.with()(id, { cases })` — see [patterns/contract-first.md](patterns/contract-first.md).

### Extend

```typescript
const authed = http.extend({
  headers: { Authorization: "Bearer ..." },
});
```

---

## Assertions — ctx.expect()

```typescript
// Equality
expect(x).toBe(y)
expect(x).toEqual(y)

// Truthiness
expect(x).toBeTruthy()
expect(x).toBeFalsy()
expect(x).toBeNull()
expect(x).toBeUndefined()
expect(x).toBeDefined()

// Numeric
expect(n).toBeGreaterThan(5)
expect(n).toBeGreaterThanOrEqual(5)
expect(n).toBeLessThan(10)
expect(n).toBeLessThanOrEqual(10)
expect(n).toBeWithin(1, 10)

// Strings & collections
expect(s).toContain("sub")
expect(s).toMatch(/regex/)
expect(s).toStartWith("pre")
expect(s).toEndWith("suf")
expect(arr).toHaveLength(3)

// Objects
expect(obj).toMatchObject({ key: "val" })
expect(obj).toHaveProperty("path.to.key", expectedValue?)
expect(obj).toHaveProperties(["a", "b"])

// HTTP responses
expect(res).toHaveStatus(200)
await expect(res).toHaveJsonBody({ key: "val" })
expect(res).toHaveHeader("content-type", /json/)

// Modifiers
expect(x).not.toBe(y)                // Negate
expect(x).toBe(y).orFail()           // Hard fail (stop test)

// Custom
expect(x).toSatisfy(v => v > 0)
expect(x).toBeType("string")
```

---

## configure()

File-level setup. Binds env vars, creates HTTP client, registers plugins.

```typescript
const { http, vars, secrets } = configure({
  vars: { user: "{{GITHUB_USER}}" },    // {{KEY}} → resolved from .env
  secrets: { token: "{{API_KEY}}" },   // {{KEY}} → resolved from .env.secrets
  http: {
    prefixUrl: "{{BASE_URL}}",         // {{KEY}} → resolved at runtime
    headers: {
      Authorization: "Bearer {{API_KEY}}",  // {{var}} interpolation
      Accept: "application/json",
    },
    timeout: 15000,
    retry: 2,
  },
});

// vars.user → reads process.env.GITHUB_USER
// secrets.token → reads from .env.secrets
// http → pre-configured client with base URL + auth headers
```

### With plugins

```typescript
const { http, chrome } = configure({
  http: { prefixUrl: "{{BASE_URL}}" },
  plugins: {
    chrome: browser({ launch: true, launchOptions: { headless: true } }),
  },
});
```

### defineClientFactory() — per-file client

For sharing a client across tests in one file via `configure({ plugins })`:

```typescript
import { configure, defineClientFactory } from "@glubean/sdk";

const myClient = defineClientFactory((runtime) => {
  const apiKey = runtime.requireSecret("MY_KEY");
  return {
    doSomething: () => { ... },
  };
});

const { myClient: instance } = configure({
  plugins: { myClient },
});
```

### definePlugin() + installPlugin() — global matchers / protocols

For shipping an npm plugin that registers matchers, protocol adapters, or one-time setup:

```typescript
// my-plugin/src/index.ts
import { definePlugin } from "@glubean/sdk";
export default definePlugin({
  name: "@me/my-plugin",
  matchers: { toBeMyThing(actual) { return { pass: ..., message: () => "..." }; } },
  contracts: { myproto: myprotoAdapter },
  setup() { /* optional one-time hook */ },
});
```

Consumers must install it in `glubean.setup.ts` at the project root:

```typescript
// glubean.setup.ts
import { installPlugin } from "@glubean/sdk";
import myPlugin from "@me/my-plugin";
await installPlugin(myPlugin);
```

The manifest has no effect until `installPlugin` runs. `glubean.setup.ts` is discovered and run exactly once per process by CLI / MCP / VSCode before any test file or `.contract.ts` loads.

---

## Data Loading

```typescript
// Directory: one JSON/YAML file = one row
const rows = await fromDir<T>("data/users/");
// Returns: [{ username: "alice", _name: "alice", _path: "data/users/alice.json" }, ...]

// Directory: merge shared + *.local.json overrides
const cases = await fromDir.merge<T>("data/search/");
// Returns: { "case-name": { q: "test", min: 5 }, ... }

// Directory: concatenate arrays from files
const items = await fromDir.concat<T>("data/items/");

// CSV
const rows = await fromCsv<T>("data/file.csv");
const rows = await fromCsv<T>("data/file.tsv", { separator: "\t" });
const rows = await fromCsv<T>("data/file.csv", { headers: false }); // numeric keys

// YAML
const rows = await fromYaml<T>("data/file.yaml");
const rows = await fromYaml<T>("data/nested.yaml", { pick: "data.testCases" }); // dot-path to array

// JSONL (one JSON object per line)
const rows = await fromJsonl<T>("data/file.jsonl");
```

### Data file conventions

- `data/` directory at project root
- Prefer bare `data/...` paths for shared project data
- `shared.json` for committed defaults
- `*.local.json` for personal overrides (gitignored)
- Each JSON or YAML file in `fromDir()` becomes one test case; filename = case name (default extensions: `.json`, `.yaml`, `.yml`)

---

## defineSession()

Define session setup/teardown for cross-file state sharing. Place in `session.ts` at your test root — the runner auto-discovers it.

```typescript
import { defineSession } from "@glubean/sdk";

export default defineSession({
  async setup(ctx) {
    const { access_token } = await ctx.http
      .post("/auth/login", {
        json: { user: ctx.vars.require("USER"), pass: ctx.secrets.require("PASS") },
      })
      .json<{ access_token: string }>();
    ctx.session.set("token", access_token);
  },
  async teardown(ctx) {
    await ctx.http.post("/auth/logout", {
      headers: { Authorization: `Bearer ${ctx.session.get("token")}` },
    });
  },
});
```

In tests, read session values with `ctx.session.require("key")` or `ctx.session.get("key")`.

---

## Browser Plugin (@glubean/browser)

### Setup

```typescript
// config/browser.ts
import { test, configure } from "@glubean/sdk";
import { browser } from "@glubean/browser";
import type { InstrumentedPage } from "@glubean/browser";

export const { chrome } = configure({
  plugins: {
    chrome: browser({
      launch: true,
      launchOptions: { headless: true },
      baseUrl: "{{APP_URL}}",           // {{KEY}} → resolved from .env
      screenshot: "on-failure",        // "off" | "on-failure" | "every-step"
      networkTrace: true,              // Auto-capture HTTP traces
    }),
  },
});

export const browserTest = test.extend({
  page: async (ctx, use) => {
    const pg = await chrome.newPage(ctx);
    try { await use(pg); }
    finally { await pg.close(); }
  },
});
```

### Page API

```typescript
// Navigation
await page.goto("https://example.com");
await page.goto("/relative");          // Uses baseUrl

// Interaction
await page.click("#button");
await page.clickAndNavigate("#link");   // Click + wait for navigation
await page.type("#input", "text");
await page.fill("#input", "value");     // Clear + type
await page.select("#dropdown", "option-value");
await page.hover("#element");
await page.press("Enter");
await page.upload("#file-input", "./path/to/file");

// Assertions (soft-fail, auto-waiting with timeout)
await page.expectText("#msg", "Welcome");
await page.expectText("#msg", /pattern/);
await page.expectURL("/dashboard");
await page.expectVisible(".success");
await page.expectHidden(".loading");

// DOM queries
const text = await page.textContent("#el");
const html = await page.innerHTML("#el");
const value = await page.inputValue("#input");
const visible = await page.isVisible("#el");

// Evaluate JS in browser
const count = await page.evaluate(() => document.querySelectorAll("li").length);

// Screenshots
await page.screenshot();               // Auto-saved as artifact

// Wait
await page.waitForURL("/target");

// Locator (auto-waiting)
await page.locator("#btn").click();
await page.locator("#input").fill("text");
```

---

## Contract API

For full contract authoring workflow: [patterns/contract-first.md](patterns/contract-first.md). For the v10 attachment model (Needs / overlays / dispatch): [patterns/attachment-model.md](patterns/attachment-model.md). This section is signature lookup only.

### `contract.http.with(name, defaults)` — scoped contract instance

Creates a reusable factory that binds a protocol name, client, and optional auth/tags. Required entry point — bare `contract.http("id", spec)` throws at runtime.

```typescript
const userApi = contract.http.with("user", {
  client: api,
  security: "bearer",   // | "basic" | { type: "apiKey", name, in } | { type: "oauth2", flows } | null
  tags: ["users"],
  extensions: { "x-owner": "platform-team" },
});
```

Returns a function `(id, spec) => Test[]`.

### `contract.http(id, spec)` — legacy (deprecated)

Bare `contract.http()` is removed. Use `contract.http.with()` and call the returned factory. Bare calls throw at runtime; the SDK does not auto-recover.

### `contract.flow(id)` — multi-step verification

Composes existing contract cases into a workflow. State flows through pure-lens `in` / `out` callbacks; non-lens transformations go in `.compute()`.

```typescript
contract.flow("user-lifecycle")
  .meta({ description: "...", tags: ["e2e"] })
  .step(createUser.case("success"), { out: (_s, res) => ({ userId: res.body.id }) })
  .step(getUser.case("success"),    { in: (s) => ({ params: { id: s.userId } }) })
  .step(deleteUser.case("success"), { in: (s) => ({ params: { id: s.userId } }) });
```

Full reference in [patterns/contract-first.md](patterns/contract-first.md) "Flow contract" section.

### `defineHttpCase<Needs>(spec)` / `defineGrpcCase<Needs>(spec)` / `defineGraphqlCase<Needs>(spec)` — case at its own const site

Type-locks the `Needs` generic across the case's `needs` schema and its function-valued action fields. Use this when the case has runtime input.

```typescript
const authorized = defineHttpCase<{ token: string }>({
  description: "Valid bearer token returns the caller's profile.",
  needs: z.object({ token: z.string() }),
  headers: ({ token }) => ({ Authorization: `Bearer ${token}` }),
  expect: { status: 200, schema: ProfileSchema },
});

// Then reference shorthand inside the contract:
export const getMe = userApi("get-me", {
  endpoint: "GET /me",
  cases: { authorized },   // shorthand — no `: { ... }` inline body
});
```

Use the protocol-specific factory for non-HTTP contracts:

```typescript
import { defineGraphqlCase } from "@glubean/graphql";

const byId = defineGraphqlCase<{ token: string; userId: string }>({
  description: "Fetches a user by authenticated id",
  needs: z.object({ token: z.string(), userId: z.string() }),
  query: "query User($id: ID!) { user(id: $id) { id name } }",
  variables: ({ userId }) => ({ id: userId }),
  headers: ({ token }) => ({ Authorization: `Bearer ${token}` }),
  expect: { httpStatus: 200, errors: "absent" },
});
```

See [patterns/attachment-model.md](patterns/attachment-model.md) for the overlay and runner input flow.

### `contract.bootstrap(caseRef, attachment)` — overlay registration

Registers a setup/cleanup overlay for a contract case. Lives in `*.bootstrap.ts` files, eagerly loaded by the harness before any test discovery.

```typescript
// me.bootstrap.ts (sibling of me.contract.ts)
import { contract } from "@glubean/sdk";
import { getMe } from "./me.contract.ts";

// Plain-function form
export const meAuthorizedOverlay = contract.bootstrap(
  getMe.case("authorized"),
  async (ctx) => {
    const res = await ctx.http.post(/* login */).json<...>();
    ctx.cleanup(/* logout / fixture cleanup */);
    return { token: res.accessToken };  // matches case `needs` shape
  },
);

// Structured form (with bootstrap-json params support)
export const meAttachOverlay = contract.bootstrap(
  getMe.case("requiresAttachment"),
  {
    params: z.object({ username: z.string(), password: z.string() }),
    run: async (ctx, { username, password }) => { /* ... */ },
  },
);
```

Full mechanics, including §5.1 dispatch and §6.3 runnability table: [patterns/attachment-model.md](patterns/attachment-model.md).

### `runCase()` — programmatic single-test entry

```typescript
import { runCase } from "@glubean/runner";

const result = await runCase({
  filePath: "me.contract.ts",
  testId: "auth.me.authorized",
  sharedConfig: { /* ... */ },

  // One of these (mutually exclusive):
  input: { token: "..." },              // explicit input — overlay skipped
  bootstrapInput: { username: "...", password: "..." },  // overlay params
  forceStandalone: true,                // debug bypass for requireAttachment
});
```

CLI equivalents: `--input-json`, `--bootstrap-json`, `--force-standalone`. See [patterns/runner-input.md](patterns/runner-input.md).

---

## CLI Commands

```bash
glubean run                            # Run all tests
glubean run tests/api/                 # Run specific directory
glubean run tests/api/health.test.ts   # Run single file
glubean run --filter smoke             # Filter by tag
glubean run --upload                   # Upload results to Cloud
glubean run --upload --tag ci          # Tag the run

# Data-driven (test.pick) — see patterns/data-driven.md
glubean run --pick all                 # Run every key (default is random-pick-1)
glubean run --pick keyA,keyB           # Run specific keys
glubean run --pick 'us-*'              # Glob pattern

# Attachment-model channels — see patterns/runner-input.md
glubean run --filter X --input-json '<JSON>'      # Explicit input bypass
glubean run --filter X --bootstrap-json '<JSON>'  # Overlay params
glubean run --filter X --force-standalone         # Debug bypass for requireAttachment
```

---

## Project Structure Convention

```
config/              # Shared HTTP clients, browser fixtures, plugin configs
  api.ts             # configure() for API under test
  browser.ts         # browser plugin + browserTest fixture
tests/
  api/               # API integration tests
  e2e/               # Browser end-to-end tests
data/                # Test data files (JSON, CSV, YAML)
glubean.yaml         # Config: suites + profiles + defaults (redaction, thresholds)
.env                 # Public variables (BASE_URL, APP_URL, GLUBEAN_PROJECT_ID)
.env.secrets         # Credentials (API_KEY, GLUBEAN_TOKEN) — gitignored
package.json         # npm deps + scripts
AGENTS.md            # AI agent instructions
```
