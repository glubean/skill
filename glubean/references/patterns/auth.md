# @glubean/auth

> **Requires:** `npm install @glubean/auth`

## Why this pattern

**Problem:** manually setting `Authorization` headers in `configure()` works for static tokens, but breaks when tokens expire, need refresh, or require a login-then-use flow.
**Alternative:** write auth logic in a builder `.step()` or a helper function — but you end up reimplementing token caching, refresh-on-401, and expiry tracking in every project.
**This pattern:** `@glubean/auth` provides declarative strategies (`bearer()`, `apiKey()`, `oauth2.clientCredentials()`, etc.) that handle caching, refresh, and header injection automatically. One line in `configure()` replaces pages of manual auth code. When moving between environments or auth types, only the `configure({ http })` line changes — test logic stays the same.

Pre-built auth strategies. Returns `ConfigureHttpOptions` — pass directly to `configure({ http: ... })`.

All values support `{{KEY}}` references (resolved from .env / .env.secrets) or literal strings.

For manual auth flows using builder steps, see [builder-reuse.md](builder-reuse.md).

## Bearer token

```typescript
import { configure } from "@glubean/sdk";
import { bearer } from "@glubean/auth";

export const { http: api } = configure({
  http: bearer({ prefixUrl: "{{BASE_URL}}", token: "{{API_TOKEN}}" }),
});
// Every request gets: Authorization: Bearer <resolved value>
```

## API key (header)

```typescript
import { apiKey } from "@glubean/auth";

export const { http: api } = configure({
  http: apiKey({ prefixUrl: "{{BASE_URL}}", param: "X-Api-Key", value: "{{API_KEY}}" }),
});
// Every request gets header: X-Api-Key: <value>
```

## API key (query param)

```typescript
import { apiKey } from "@glubean/auth";

export const { http: api } = configure({
  http: apiKey({ prefixUrl: "{{BASE_URL}}", param: "apiKey", value: "{{API_KEY}}", location: "query" }),
});
// Every request gets: ?apiKey=<value>
```

## Basic auth

```typescript
import { basicAuth } from "@glubean/auth";

export const { http: api } = configure({
  http: basicAuth({ prefixUrl: "{{BASE_URL}}", username: "{{USER}}", password: "{{PASS}}" }),
});
// Every request gets: Authorization: Basic base64(user:pass)
```

## OAuth2 — client credentials

```typescript
import { oauth2 } from "@glubean/auth";

export const { http: api } = configure({
  http: oauth2.clientCredentials({
    prefixUrl: "{{BASE_URL}}",
    tokenUrl: "{{OAUTH_TOKEN_URL}}",
    clientId: "{{CLIENT_ID}}",
    clientSecret: "{{CLIENT_SECRET}}",
    scope: "read write",              // Optional
  }),
});
// Auto-fetches token, caches it, refreshes before expiry
```

## OAuth2 — refresh token

```typescript
import { oauth2 } from "@glubean/auth";

export const { http: api } = configure({
  http: oauth2.refreshToken({
    prefixUrl: "{{BASE_URL}}",
    tokenUrl: "{{OAUTH_TOKEN_URL}}",
    refreshToken: "{{REFRESH_TOKEN}}",
    clientId: "{{CLIENT_ID}}",
    clientSecret: "{{CLIENT_SECRET}}",    // Optional
  }),
});
// Auto-refreshes on 401
```

## OAuth2 — authorization code (interactive, explore only)

> **Requires:** `npm install @glubean/oauth-code`

For APIs that only support authorization code flow (no client_credentials, no pre-existing token). Opens the system browser on first request, caches tokens to disk, auto-refreshes.

```typescript
import { configure } from "@glubean/sdk";
import { oauthCode } from "@glubean/oauth-code";

export const { http: api } = configure({
  http: oauthCode({
    prefixUrl: "{{BASE_URL}}",
    authorizeUrl: "{{OAUTH_AUTHORIZE_URL}}",
    tokenUrl: "{{OAUTH_TOKEN_URL}}",
    clientId: "{{CLIENT_ID}}",
    clientSecret: "{{CLIENT_SECRET}}",
    scopes: ["read", "write"],
  }),
});
// First run: opens browser for login. Subsequent runs: uses cached token.
```

### Tunnel for non-localhost providers

Some providers (e.g. Twitter/X, Slack) don't support `localhost` redirect URIs. When the agent detects these from the authorize URL, proactively explain the tunnel requirement:

```typescript
oauthCode({
  // ...
  redirectUri: "https://xxx.ngrok-free.app/callback",
  port: 9876,
})
```

The user needs to run an HTTPS tunnel (e.g. `ngrok http 9876`) and register the tunnel URL as a redirect URI with the provider.

### Explore → CI promotion

When moving tests from `explore/` to `tests/`, replace `oauthCode()` with a non-interactive strategy. Test logic stays the same — only the `configure({ http })` line changes.

| CI strategy | When to use |
|---|---|
| `oauth2.clientCredentials()` | Provider supports it |
| `oauth2.refreshToken()` | Pre-provision a refresh token, store as CI secret |
| `bearer()` | Pre-provision an access token |

## OAuth2 decision tree

When an API requires OAuth2, use this decision order:

```
API requires OAuth2?
├─ Supports client_credentials? → use oauth2.clientCredentials() (works everywhere)
├─ Has pre-existing refresh_token? → use oauth2.refreshToken() (works everywhere)
├─ Only authorization code flow?
│  ├─ Writing to explore/? → suggest oauthCode() + explain browser interaction
│  └─ Writing to tests/? → warn: needs non-interactive alternative for CI
│     Options: get refresh_token locally → store as CI secret → use oauth2.refreshToken()
└─ No OAuth2? → check other auth types (bearer, apiKey, basic)
```

## withLogin — builder transform

```typescript
import { test } from "@glubean/sdk";
import { withLogin } from "@glubean/auth";

const login = withLogin({
  endpoint: "{{BASE_URL}}/auth/login",
  credentials: { username: "{{USERNAME}}", password: "{{PASSWORD}}" },
  extractToken: (body) => body.token,
});

export const protectedTest = test("protected")
  .use(login)
  .step("access", async (ctx, { authedHttp }) => {
    const res = await authedHttp.get("https://api.example.com/me").json<{ id: string }>();
    ctx.expect(res.id).toBeDefined();
  });
```

## Combining auth strategies

When mixing `apiKey()` with custom headers, extract the base config and spread its `headers`:

```typescript
import { configure } from "@glubean/sdk";
import { apiKey } from "@glubean/auth";

const base = apiKey({ prefixUrl: "{{BASE_URL}}", param: "apiKey", value: "{{API_KEY}}", location: "query" });

export const { http } = configure({
  http: {
    ...base,
    headers: {
      ...base.headers,   // ← preserve plugin's internal headers
      Authorization: "Bearer {{TOKEN}}",
    },
  },
});
```

> **Why?** `apiKey({ location: "query" })` and `basicAuth()` use marker headers + beforeRequest hooks internally. Overwriting `headers` without spreading `base.headers` drops the marker and the hook silently does nothing.
