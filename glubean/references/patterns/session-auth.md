# Session Auth — Dynamic Token Acquisition for Contracts

## Why this pattern

**Problem:** your project uses social login (Google, GitHub, Apple), magic link, SMS OTP, or another interactive auth method. 90% of your contracts need an authenticated JWT, but the JWT can only be obtained through an interactive ceremony that CI can't reproduce.

**Alternative:** put interactive auth tests in `explore/` and only test unauthenticated cases in `contracts/` — but that means your contract suite never verifies any authenticated behavior, which is most of your API.

**This pattern:** use `session.ts` to dynamically acquire a test token before any contract runs, then inject it into `configure()` via `{{KEY}}` templates. Contracts are completely unaware of how the token was obtained. Two run modes — bypass (headless, safe) and real auth (interactive, opt-in) — are controlled by a single CLI flag.

Keywords: OAuth, Google login, GitHub login, Apple Sign In, magic link, Resend, SMS OTP, Twilio, social login, dev-bypass, test-login endpoint, session setup.

## Important: where {{KEY}} works

`{{KEY}}` template resolution only applies inside `configure({ http: { ... } })` — specifically in `prefixUrl`, `headers`, and `searchParams`. It does **not** interpolate contract case `body` fields (those are static objects serialized as-is).

This means: you cannot inject a session token into a contract body via `body: { token: "{{AUTH_TOKEN}}" }` — the literal string `"{{AUTH_TOKEN}}"` would be sent to the server.

The session pattern works around this by putting the token into a configured client's auth header (`bearer()` or `Authorization: "Bearer {{AUTH_TOKEN}}"`), not into the body. The token flows through the HTTP client layer, invisible to contracts.

## Three-layer separation

```
session.ts          → HOW to get the token (user code, 10-20 lines)
config/client.ts    → SHAPE of the HTTP client (pure declarative)
contracts/*.ts      → WHAT the API should do (pure specification)
```

| Layer | Knows | Does not know |
|---|---|---|
| session.ts | How to get a token (bypass or real auth) | Which contracts will use it |
| configure | Client shape (`bearer + prefixUrl`) | Where the token came from |
| contract | API behavior spec | Anything about auth implementation |

## Two run modes

The same `session.ts` handles both modes. The branch signal is `ctx.interactive` — set by the CLI `--include-browser` flag.

| Command | `ctx.interactive` | Session path | Contract behavior |
|---|---|---|---|
| `glubean run` | `false` | bypass (headless) | `requires: "browser"` cases skip |
| `glubean run --include-browser` | `true` | real auth (browser/OOB) | all cases run |

**Default is always headless.** Agent-triggered, editor-triggered, CI, and scripted runs never pop a browser. Real auth is always an explicit human gesture.

Recommended `package.json` scripts:

```json
{
  "scripts": {
    "test": "glubean run",
    "test:real-auth": "glubean run --include-browser"
  }
}
```

**When to use each:**
- `npm test` — daily development, CI, agent loops. Fast, headless, safe.
- `npm run test:real-auth` — release ritual, incident reproduction, day-0 backend-only verification. Runs real OAuth (browser pops on first use only, cached after that).

## Complete example: Google Login project

### session.ts

```typescript
import { defineSession } from "@glubean/sdk";
import { publicHttp } from "../config/client.js";

export default defineSession({
  async setup(ctx) {
    if (ctx.interactive) {
      // Real OAuth — user passed --include-browser.
      // First run opens browser; subsequent runs use disk cache silently.
      const { acquireOAuthToken } = await import("@glubean/oauth-code");
      const { access_token } = await acquireOAuthToken({
        authorizeUrl: "https://accounts.google.com/o/oauth2/v2/auth",
        tokenUrl: "https://oauth2.googleapis.com/token",
        clientId: ctx.secrets.require("GOOGLE_CLIENT_ID"),
        clientSecret: ctx.secrets.require("GOOGLE_CLIENT_SECRET"),
        scopes: ["openid", "email", "profile"],
      });
      // Exchange Google token for app JWT
      const res = await publicHttp.post("auth/google/callback", {
        json: { token: access_token },
      });
      ctx.session.set("AUTH_TOKEN", (await res.json()).token);
    } else {
      // Bypass — default, headless.
      // Calls a secret-gated test endpoint on your backend.
      const res = await publicHttp.post("auth/test-login", {
        headers: { "x-test-auth": ctx.secrets.require("GLUBEAN_TEST_AUTH_TOKEN") },
        json: { email: "alice@test.com", role: "user" },
      });
      ctx.session.set("AUTH_TOKEN", (await res.json()).token);
    }
  },
});
```

### config/client.ts

```typescript
import { configure } from "@glubean/sdk";
import { bearer } from "@glubean/auth";

export const { http: api } = configure({
  http: bearer({ prefixUrl: "{{BASE_URL}}", token: "{{AUTH_TOKEN}}" }),
});

export const { http: publicHttp } = configure({
  http: { prefixUrl: "{{BASE_URL}}" },
});
```

No plumbing, no branching. `{{AUTH_TOKEN}}` resolves from session transparently.

### contracts/projects/create.contract.ts

```typescript
import { contract } from "@glubean/sdk";
import { api, publicHttp } from "../../config/client.js";
import { ProjectSchema } from "../../schemas/Project.js";

export const createProject = contract.http("create-project", {
  endpoint: "POST /projects",
  description: "Create a new project.",
  client: api,
  cases: {
    success: {
      description: "Valid input returns 201 with project object.",
      body: { name: "My Project", description: "Test" },
      expect: { status: 201, schema: ProjectSchema },
    },
    noAuth: {
      description: "Unauthenticated request returns 401.",
      client: publicHttp,
      expect: { status: 401 },
    },
  },
});
```

Zero awareness of OAuth, bypass, session, or tokens.

### contracts/auth/google-callback.contract.ts

This is the **one** contract that tests the real OAuth callback itself. It uses `requires: "browser"` because it genuinely needs Google's interactive flow.

**Note:** this is a narrow exception to the three-layer separation. The OAuth callback contract is the *only* place where an auth-specific client appears in a contract file — because verifying the callback endpoint *is* the auth flow. All other contracts use the shared `api` client from `config/client.ts` and have zero auth awareness.

```typescript
import { contract } from "@glubean/sdk";
import { oauthClient } from "../../config/oauth-client.js";

export const googleCallback = contract.http("google-callback", {
  endpoint: "POST /auth/google/callback",
  description: "Exchange Google ID token for app session JWT.",
  client: oauthClient,
  cases: {
    success: {
      description: "Valid Google token returns app JWT.",
      requires: "browser",
      // Contract body is static — {{KEY}} does not interpolate here.
      // The access_token from the OAuth flow cannot be injected into body today.
      // Use session.ts bypass path to verify authenticated behavior end-to-end.
      deferred: "contract body cannot carry dynamic OAuth token; verify via session.ts bypass",
      expect: { status: 200 },
    },
    invalidToken: {
      description: "Forged token is rejected.",
      body: { token: "obviously-fake" },
      expect: { status: 401 },
    },
  },
});
```

The `oauthCode` client lives in `config/oauth-client.ts` — not inline in the contract:

```typescript
// config/oauth-client.ts — auth-specific client, only imported by the callback contract
import { configure } from "@glubean/sdk";
import { oauthCode } from "@glubean/oauth-code";

export const { http: oauthClient } = configure({
  http: oauthCode({
    prefixUrl: "{{BASE_URL}}",
    authorizeUrl: "https://accounts.google.com/o/oauth2/v2/auth",
    tokenUrl: "https://oauth2.googleapis.com/token",
    clientId: "{{GOOGLE_CLIENT_ID}}",
    clientSecret: "{{GOOGLE_CLIENT_SECRET}}",
    scopes: ["openid", "email", "profile"],
  }),
});
```

`invalidToken` runs in CI (headless). `success` only runs with `--include-browser`.

### package.json

```json
{
  "scripts": {
    "test": "glubean run",
    "test:real-auth": "glubean run --include-browser"
  }
}
```

### .env

```
BASE_URL=http://localhost:3000
```

### .env.secrets

```
GLUBEAN_TEST_AUTH_TOKEN=<your-secret-here>
GOOGLE_CLIENT_ID=<from-google-console>
GOOGLE_CLIENT_SECRET=<from-google-console>
```

**GitHub OAuth note:** GitHub does exact host matching on redirect URIs. `localhost` and `127.0.0.1` are different hosts — registering `localhost` when `acquireOAuthToken` binds to `127.0.0.1` causes a `redirect_uri_mismatch` error. Always register `http://127.0.0.1` (no port) in your OAuth app settings. GitHub follows RFC 8252 loopback exemption: it accepts any port on `127.0.0.1` at runtime.

## Backend: test-login endpoint (example)

This is **one common approach** for the bypass path — not a requirement. Your team may have other ways to provide test credentials (admin API token, service account, framework test auth, etc.).

```typescript
// Example: Express/Hono/Fastify backend
const TEST_AUTH_TOKEN = process.env.GLUBEAN_TEST_AUTH_TOKEN;

if (TEST_AUTH_TOKEN) {
  app.post("/auth/test-login", async (req, res) => {
    if (req.headers["x-test-auth"] !== TEST_AUTH_TOKEN) {
      return res.status(401).json({ error: "unauthorized" });
    }
    const { email, role = "user" } = req.body;
    const user = await db.users.upsert({ email, role });
    const token = signAppJwt(user);  // real JWT signing path
    res.json({ token });
  });
}
```

This endpoint:
- Runs your real user creation + JWT signing code (not mock)
- Is gated by a secret header (not `NODE_ENV`)
- Can be enabled in any environment where the secret is injected
- Injection is a deployment decision — Glubean does not prescribe which environments

## Adapting to other auth types

The same session pattern works for any auth method. Only the `ctx.interactive` branch changes:

### Magic link + Resend

```typescript
import { publicHttp } from "../config/client.js";

if (ctx.interactive) {
  await publicHttp.post("auth/magic-link", { json: { email: "test@example.com" } });
  const { Resend } = await import("resend");
  const resend = new Resend(ctx.secrets.require("RESEND_API_KEY"));
  const link = await pollForMagicLink(resend, "test@example.com");
  const res = await publicHttp.get(link);
  ctx.session.set("AUTH_TOKEN", (await res.json()).token);
} else {
  // bypass — same as above
}
```

### Email + password (no interactive needed)

```typescript
import { publicHttp } from "../config/client.js";

// No branching needed — email+password is headless
const res = await publicHttp.post("auth/login", {
  json: {
    email: ctx.secrets.require("TEST_EMAIL"),
    password: ctx.secrets.require("TEST_PASSWORD"),
  },
});
ctx.session.set("AUTH_TOKEN", (await res.json()).token);
```

### Static API key (no session needed)

```typescript
// No session.ts at all — use .env.secrets directly
export const { http: api } = configure({
  http: apiKey({ prefixUrl: "{{BASE_URL}}", param: "X-Api-Key", value: "{{API_KEY}}" }),
});
```

## Session setup: handling HTTP errors

The default configured client inherits `throwHttpErrors: false` — this is intentional for test assertions (`expect(res).toHaveStatus(401)` must work). But in session setup, a failed auth request (e.g. test-login returns 404) won't throw — `AUTH_TOKEN` gets set to `undefined`, and subsequent tests run with a broken token, producing misleading failures.

If your session setup should hard-fail on any HTTP error, use a dedicated client with `throwHttpErrors: true`:

```typescript
// config/client.ts
export const { http: sessionHttp } = configure({
  http: { prefixUrl: "{{BASE_URL}}", throwHttpErrors: true },
});

export const { http: publicHttp } = configure({
  http: { prefixUrl: "{{BASE_URL}}" },
});
```

```typescript
// session.ts
import { sessionHttp } from "../config/client.js";

// Now a 404 or 500 from test-login throws immediately — session setup fails loudly
const res = await sessionHttp.post("auth/test-login", { ... });
```

Use `sessionHttp` only in `session.ts`. Tests continue to use `api` and `publicHttp`.

## MCP and CI

MCP-triggered runs (agent tool calls) and CI are both headless. They always get `ctx.interactive = false` and walk the bypass path. No special handling needed.

## Anti-patterns

- **Do not** use `NODE_ENV !== "production"` to gate the test-login endpoint — it locks out production and is not a reliable boundary. Use a secret header.
- **Do not** put all auth-dependent contracts in `explore/` — that defeats contract-first. Use session auth so they run in CI via bypass.
- **Do not** mock your own backend to avoid the auth problem — dev-bypass runs your real code. See [contract-case-runtime proposal](../../../internal/40-discovery/proposals/contract-case-runtime.md) for why.
- **Do not** use `requires: "browser"` on `/me`, `/projects`, or other business contracts just because the project uses OAuth — those contracts need *any* authenticated token, not specifically a Google token. Session bypass handles this.
- **Do not** hard-code the choice of bypass vs real auth in session.ts without `ctx.interactive` — this would make local runs unexpectedly interactive when the user just wants a quick headless check.
