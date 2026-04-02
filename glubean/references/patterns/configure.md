# Configure — Shared HTTP Clients, Vars, Secrets, Plugins

## Why this pattern

**Problem:** writing `fetch("https://api.example.com/users", { headers: { Authorization: "Bearer sk-xxx" } })` in every test duplicates the base URL, auth, and timeout config — and hardcodes secrets in source code.
**Alternative:** use `ctx.http.extend()` per test — but this still requires every test to know the base URL and auth headers, there is no centralized place to change them, and secrets are not managed.
**This pattern:** `configure()` creates a shared HTTP client with `{{KEY}}` interpolation from `.env` / `.env.secrets`. One file (`config/api.ts`) controls base URL, auth, headers, and plugins for every test that imports it. Change the URL once, every test follows. Secrets never appear in source code.

## .env vs .env.secrets — what goes where?

| File | What goes here | Committed to git? | Example |
|------|---------------|-------------------|---------|
| `.env` | Public config: URLs, usernames, feature flags | Yes | `BASE_URL=https://api.example.com` |
| `.env.secrets` | Credentials: API keys, tokens, passwords | **No** (gitignored) | `API_KEY=sk-live-xxx` |

**Rule of thumb:** if leaking it would be a security risk, it goes in `.env.secrets`.

In code, use `{{KEY}}` to reference values from either file — the SDK resolves from secrets first, then vars.

```
.env:
  BASE_URL=https://api.example.com
  GITHUB_USER=glubean

.env.secrets:
  API_KEY=sk-live-xxx
  GITHUB_TOKEN=ghp_xxx
```

## Basic API client

```typescript
// config/api.ts
import { configure } from "@glubean/sdk";

export const { http: api, vars, secrets } = configure({
  vars: { user: "{{GITHUB_USER}}" },        // {{KEY}} → resolved from .env
  secrets: { token: "{{API_KEY}}" },         // {{KEY}} → resolved from .env.secrets
  http: {
    prefixUrl: "{{BASE_URL}}",              // {{KEY}} → resolved at runtime
    headers: {
      Authorization: "Bearer {{API_KEY}}",  // {{KEY}} → resolved from .env.secrets
      Accept: "application/json",
    },
    timeout: 15000,
    retry: 2,
  },
});
```

`.env`:
```
BASE_URL=https://api.example.com
GITHUB_USER=glubean
```

`.env.secrets`:
```
API_KEY=sk_live_xxx
```

## Quick prototyping — literal values

All values support literal strings too. Skip `.env` files when you just want to try something:

```typescript
export const { http: api } = configure({
  http: {
    prefixUrl: "https://api.example.com",    // literal URL
    headers: {
      Authorization: "Bearer sk-test-123",   // literal token (don't commit this!)
    },
  },
});
```

You can also mix:

```typescript
export const { http: api, vars } = configure({
  vars: { baseUrl: "{{BASE_URL}}", debugMode: "true" },  // ref + literal
  http: { prefixUrl: "{{BASE_URL}}" },
});
```

**Rule:** `{{KEY}}` = resolve from .env/.env.secrets at runtime. No `{{}}` = literal value.

## Using the configured client in tests

```typescript
// tests/users.test.ts
import { test } from "@glubean/sdk";
import { api } from "../config/api";

export const getUser = test(
  { id: "get-user", tags: ["users"] },
  async (ctx) => {
    const res = await api.get("users/1");
    ctx.expect(res.status).toBe(200);
  },
);
```

Import the exported client (`api`), not `ctx.http`. The configured client has base URL, auth, and timeout baked in.

## With auth plugin

For anything beyond static headers, use `@glubean/auth` instead of manually setting `Authorization`:

```typescript
import { configure } from "@glubean/sdk";
import { bearer } from "@glubean/auth";

export const { http: api } = configure({
  http: bearer({ prefixUrl: "{{BASE_URL}}", token: "{{API_TOKEN}}" }),
});
```

Available strategies: `bearer()`, `apiKey()`, `basicAuth()`, `oauth2.clientCredentials()`, `oauth2.refreshToken()`, `oauthCode()`. See [auth.md](auth.md) for the full reference and OAuth2 decision tree.

## Public + Authenticated clients (same API, different auth)

```typescript
// config/github-api.ts
import { configure } from "@glubean/sdk";

// Public — no token needed
export const { http: githubApi, vars: githubVars } = configure({
  vars: {
    user: "{{GITHUB_USER}}",
    repo: "{{GITHUB_REPO}}",
    searchQuery: "{{GITHUB_SEARCH_QUERY}}",
  },
  http: {
    prefixUrl: "{{GITHUB_API}}",
    headers: { Accept: "application/vnd.github+json" },
  },
});

// Authenticated — requires GITHUB_TOKEN in .env.secrets
export const { http: githubAuthApi } = configure({
  secrets: { token: "{{GITHUB_TOKEN}}" },
  http: {
    prefixUrl: "{{GITHUB_API}}",
    headers: {
      Authorization: "Bearer {{GITHUB_TOKEN}}",
      Accept: "application/vnd.github+json",
    },
  },
});
```

## With browser plugin

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
    }),
  },
});

// Per-test page fixture — auto-closed after test
export const browserTest = test.extend({
  page: async (ctx, use: (instance: InstrumentedPage) => Promise<void>) => {
    const pg = await chrome.newPage(ctx);
    try { await use(pg); }
    finally { await pg.close(); }
  },
});
```

## With custom plugin (AI example)

```typescript
// config/ai.ts
import { configure, definePlugin } from "@glubean/sdk";
import { generateObject } from "ai";
import { createOpenAI } from "@ai-sdk/openai";
import type { ZodType } from "zod";

export const { ai } = configure({
  plugins: {
    ai: definePlugin((rt) => {
      const openai = createOpenAI({
        apiKey: rt.requireSecret("OPENAI_API_KEY"),
      });
      return {
        generate: <T>(schema: ZodType<T>, prompt: string, model = "gpt-4o-mini") =>
          generateObject({ model: openai(model), schema, prompt }),
      };
    }),
  },
});
```

## Anti-patterns

```typescript
// ❌ Using ctx.http (only for scratch demos)
const res = await ctx.http.get("https://api.example.com/users");

// ✅ Use configured client
const res = await api.get("users").json();

// ❌ Hardcoded URL
const res = await fetch("https://api.example.com/users");

// ✅ Use configured client
const res = await api.get("users").json();

// ❌ Hardcoded secret
headers: { Authorization: "Bearer sk_live_xxx" }

// ✅ Use secrets interpolation or require
headers: { Authorization: "Bearer {{API_KEY}}" }
// or in test: ctx.secrets.require("API_KEY")

// ❌ Inline const for base URL
const BASE_URL = "https://api.example.com";

// ✅ Put in .env
// .env: BASE_URL=https://api.example.com
// configure: http: { prefixUrl: "{{BASE_URL}}" }
```
