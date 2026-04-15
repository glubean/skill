# Contract-First: Executable Contracts Before Implementation

## Why this pattern

**Problem:** AI agents jump from vague product intent straight to code implementation. Without an intermediate alignment step, the agent guesses too much — wrong status codes, invented field names, missing error cases, broken cross-endpoint contracts.

**Alternative:** write an OpenAPI spec first — but OpenAPI cannot express workflow contracts (data flowing between endpoints), and the spec-to-implementation gap still requires manual codegen or translation.

**This pattern:** write `contract.http.with()` scoped instances and then declare contracts before the API exists. Each contract defines endpoint, request shape, response schema, status codes, error cases, and auth boundaries as structured, executable cases. AI reads these contracts to implement the API. The contracts remain the source of truth and are continuously verified.

## How it differs from test-after

| | Test-after | Contract-first |
|---|---|---|
| API state | Exists, callable | Does not exist or partially implemented |
| Information source | OpenAPI spec / context/ / traces | User intent + existing codebase conventions |
| API | `test()` — imperative, free-form | `contract.http.with()` — declarative, structured |
| Response contract | Inferred from traces or existing schema | Defined from intent, prefer Zod schema |
| Auth | Requires real credentials | Can use placeholders, but auth semantics still need user confirmation |
| Failure is normal? | No — fix needed | Yes — server not implemented yet |

## Directory convention

```
schemas/     ← Zod response schemas
contracts/   ← contract.http.with() instances + specs + contract.flow() verification
tests/       ← test() for cases contract can't express (browser, polling)
explore/     ← free exploration, ad-hoc verification
```

Why separate:
- `contracts/` failure means "intent not aligned" or "implementation not done" — `tests/` failure means "stable behavior regressed"
- `contract.http.with()` produces `Test[]` directly — runner executes them without promotion
- mixing contract specs and ad-hoc tests makes it impossible to generate projection/coverage reports
- contracts sharing a client should use one `.with()` instance — keep the instance declaration in a shared file or at the top of the contract file

Lifecycle: `contracts/` (define) → implementation → run contracts until green

`contract.http.with()` produces standard `Test[]`, so `glubean run contracts` works out of the box.

## Writing contracts

Before writing contract files:

1. Read `GLUBEAN.md` when it exists.
2. Read any user-provided context (OpenAPI specs, docs, issue URLs) before making technical decisions.
3. **Pass the intent gate** (see below) — do not skip this step.
4. Choose the right contract scope.

### Intent gate — ask before you write

**Before writing a single line of contract code**, state explicitly what you understood, and verify each item is clear. If any item is unclear, STOP and ask the user — do not guess.

The intent gate checklist:

1. **Endpoints** — which HTTP method + path(s)?
2. **Auth** — which client (API key? public? specific role?)? Is the answer "I don't know" acceptable or blocking? **If auth involves OAuth, social login, magic link, or any interactive ceremony**: ask the user *"Does your backend have a way for contracts to get a test token programmatically? If not, I can show a common approach."* Then read [patterns/session-auth.md](session-auth.md) before writing any auth-dependent contract. Do not write `requires: "browser"` on business contracts — those need session auth, not interactive marking.
3. **Success response shape** — what fields are in the happy path response? If unclear, which fields are contractually required vs optional?
4. **Status codes** — what's the success code (200/201/204)? What error codes should exist (400, 401, 403, 404, 409, 422)?
5. **Request body** (for POST/PUT/PATCH) — what fields are required? Which are optional?
6. **Business rules** — any state-based restrictions (e.g. "cannot cancel completed run", "viewer role cannot delete")?
7. **State flow** (for `contract.flow()` only) — what state does each step pass to the next? What's the lifecycle order?

**How to use the gate:**

- For each item, write what you understood in one sentence
- Mark any item you're guessing with ❓
- If ANY item is marked ❓, stop and present the summary to the user
- Only after the user confirms or corrects each ❓ item, proceed to write the contract

**Example:**

```
Intent gate for "create-user":

1. Endpoint: POST /users ✓
2. Auth: API key with admin role ❓  (user said "authenticated" — not clear which role)
3. Response shape: { id, name, email, createdAt } ✓
4. Status codes: 201 success, 400 validation, 409 duplicate email ✓
5. Request body: { name: string, email: string } — both required ❓ (is phone optional?)
6. Business rules: email must be unique (409 on duplicate) ✓
7. State flow: N/A (single endpoint)

Two ❓ items — stopping to ask:
- What role is required? admin, or any authenticated user?
- Are there optional fields like phone or avatar?
```

**Never skip this gate.** Writing a contract based on assumptions produces wrong contracts that mislead both human reviewers and future agents. A 30-second clarification question is always cheaper than a wrong contract.

### Choose the right scope

- **Single-endpoint contract**: one endpoint with clear behavior cases
- **Resource contract set**: a new resource or a related group of endpoints such as CRUD + list/query
- **Flow contract**: multi-step behavior spanning multiple endpoints (verification)

### Scoped instances — `contract.http.with()`

Before writing any contract, create a scoped instance. This binds a protocol name, client, and optional security/tags to a reusable factory:

```typescript
import { contract } from "@glubean/sdk";

const userApi = contract.http.with("user", {
  client: api,
  security: "bearer",
  tags: ["users"],
});
```

`contract.http.with(name, defaults)` parameters:
- **`name`** (required) — instance identity used for projection grouping and OpenAPI output
- **`client`** (required) — the HTTP client all contracts from this instance inherit
- **`security`** — auth declaration: `"bearer"` | `"basic"` | `{ type: "apiKey", name, in }` | `{ type: "oauth2", flows }` | `null`
- **`tags`** — string array. Tags merge additively: instance tags + contract tags + case tags

Multiple instances per project are common — one per auth boundary:

```typescript
const publicApi = contract.http.with("public", { client: publicHttp, security: null });
const userApi   = contract.http.with("user",   { client: api, security: "bearer" });
const adminApi  = contract.http.with("admin",  { client: adminHttp, security: "bearer" });
```

### Single-endpoint contract

Use a scoped instance with `cases`. Each case must have a `description` explaining why it exists. Every exported contract must be preceded by `// @contract` on the line above.

```typescript
import { contract } from "@glubean/sdk";
import { z } from "zod/v4";

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email(),
  createdAt: z.string().datetime(),
});

const userApi   = contract.http.with("user",   { client: api, security: "bearer" });
const publicApi = contract.http.with("public", { client: publicHttp, security: null });

// @contract
export const createUser = userApi("create-user", {
  endpoint: "POST /users",
  description: "Create a new user account.",
  request: UserSchema, // endpoint-level schema for scanner/docs
  cases: {
    success: {
      description: "Valid user data returns 201 with user object.",
      body: { name: "Alice", email: "alice@example.com" },
      expect: { status: 201, schema: UserSchema },
      verify: async (ctx, user) => {
        ctx.expect(user.name).toBe("Alice");
      },
    },
    invalidBody: {
      description: "Missing required fields returns 400.",
      body: {},
      expect: { status: 400 },
    },
    noAuth: {
      description: "Unauthenticated request returns 401.",
      client: publicHttp,  // per-case client override still works
      body: { name: "Alice", email: "alice@example.com" },
      expect: { status: 401 },
    },
    viewerBlocked: {
      description: "Viewer role cannot create users. Requires admin.",
      client: viewerApi,
      expect: { status: 403 },
      deferred: "needs VIEWER_API_KEY credential",
    },
  },
});
```

**`// @contract` marker:** Every `export const` that is a contract must be preceded by `// @contract` on the line above. This is a marker for VSCode CodeLens — it tells the editor where contracts are. It carries no semantic information; it is purely a UI hint.

**`noAuth` pattern:** In the old `contract.http()` syntax, unauthenticated cases used `client: publicHttp` inline. In the new syntax you have two options:
1. Per-case `client` override (shown above) — the case overrides the instance's client
2. Separate public instance — create a `publicApi` instance and write the noAuth case as a separate contract under that instance

Rules:
- Each case has a required `description` — explains the business logic or boundary
- `expect.schema` validates response shape via Zod (or any SchemaLike)
- `verify` callback runs after schema validation for business-logic assertions
- `deferred` marks cases that can't run yet (missing credentials, infrastructure)
- `client` per case still works — overrides the instance's client for that case
- `client` is never set at the spec level — it is inherited from the `.with()` instance
- In real projects, move Zod schemas to `schemas/`

### Description writing rules

Descriptions appear in `glubean contracts` projection output — they are the primary way PMs and non-developers understand what the API does. Write them in **business language**, not HTTP terminology.

| Bad | Good |
|-----|------|
| POST creates a user | Valid registration creates user and returns profile |
| Returns 409 on duplicate | Already registered email is rejected |
| Validates request body | Missing required field returns validation error |
| GET endpoint returns 200 | Existing product returns full details |

`glubean contracts` runs 4 lint rules on descriptions and emits warnings:
1. Description starts with HTTP method (GET, POST, PUT, PATCH, DELETE)
2. Description contains a status code (e.g. "returns 201")
3. Description contains "status code"
4. Description contains technical jargon: "endpoint", "request body", "response body", "payload"

If you write a description that triggers a lint warning, **rewrite it immediately** — don't wait for the user to notice. The goal is that a PM can read the projection output and understand what each case tests without any HTTP knowledge.

### Resource contract set

When the user asks for a new resource, plan the full surface first:

```text
contracts/
  users/
    _instance.ts                 ← shared contract.http.with() instance(s)
    create-user.contract.ts
    get-user.contract.ts
    list-users.contract.ts
    update-user.contract.ts
    delete-user.contract.ts
    users-lifecycle.contract.ts  ← contract.flow()
```

Rules:
- Plan the full resource surface first, even if you only implement part now
- Keep one primary behavior per file
- Contracts sharing a client should import from a shared instance file (e.g. `_instance.ts`)
- Use `contract.flow()` for lifecycle verification (create → read → update → delete)

### Flow contract (cross-endpoint verification)

Use `contract.flow()` to verify that endpoints work together:

```typescript
export const userLifecycle = contract.flow("user-lifecycle")
  .http("create", {
    endpoint: "POST /users",
    client: api,
    body: { name: "Alice", email: "alice@example.com" },
    expect: { status: 201, schema: UserSchema },
    returns: (res) => ({ userId: res.id }),
  })
  .http("read back", {
    endpoint: "GET /users/:id",
    client: api,
    params: (state: { userId: string }) => ({ id: state.userId }),
    expect: { status: 200, schema: UserSchema },
    verify: async (ctx, user) => {
      ctx.expect(user.name).toBe("Alice");
    },
  })
  .http("delete", {
    endpoint: "DELETE /users/:id",
    client: api,
    params: (state: { userId: string }) => ({ id: state.userId }),
    expect: { status: 200 },
  })
  .build();
```

Key points:
- `returns(res, state)` extracts state for the next step (replace semantics)
- `params(state)` derives URL params from previous step's state
- Flow is **verification** — it proves endpoints work together, not a spec definition
- Each endpoint should also have its own `contract.http.with()` spec for case coverage

### Error contract

Define expected error responses explicitly:

```typescript
const userApi = contract.http.with("user", { client: api, security: "bearer" });

// @contract
export const createUserDuplicate = userApi("create-user-errors", {
  endpoint: "POST /users",
  description: "Error cases for user creation.",
  cases: {
    duplicate: {
      description: "Duplicate email returns 409 with EMAIL_EXISTS error code.",
      setup: async () => {
        // Create a user first to cause duplicate
        await api.post("users", { json: { name: "Alice", email: "existing@example.com" } });
      },
      body: { name: "Alice", email: "existing@example.com" },
      expect: { status: 409, schema: z.object({ error: z.literal("EMAIL_EXISTS") }) },
      teardown: async () => {
        // Clean up
      },
    },
  },
});
```

## Escalation — the critical rule

**When the user's intent is ambiguous, contradictory, or missing necessary detail, the agent MUST stop and ask — not guess.**

This is the single most important behavior in contract-first mode. Without it, the agent is just generating contracts from assumptions.

Examples of when to escalate:

- The user says "return the user" but doesn't specify which fields
- One part of the requirement says "return ID only", another says "return the full object"
- Auth strategy is mentioned but not specified (Bearer? API key? OAuth?)
- Error behavior is not described (what happens on duplicate? on not found?)
- The requirement mentions a workflow but doesn't specify the order of operations
- The project uses OAuth / social login / magic link but there is no `session.ts` and no clear plan for how contracts will get test tokens — escalate and suggest [session-auth pattern](session-auth.md) before writing any auth-dependent contract

When escalating:
1. Write what you understood as a draft contract
2. Mark unresolved parts with `deferred` or comments
3. Present the conflict or ambiguity to the user
4. Wait for confirmation before finalizing

## Agent behavior

### Writing contracts

When writing contracts, follow this order:

1. **Create the scoped instance first:** `const api = contract.http.with("name", { client, security })`
2. **Write each contract with the `// @contract` marker** on the line above the export
3. **Never write bare `contract.http("id", spec)`** — it will throw at runtime. Always use a `.with()` instance.
4. **`client` belongs in `.with()`, not in the spec** — per-case `client` overrides are still allowed

### New feature flow

1. User describes intent → create `.with()` instance + draft contracts in `contracts/`
2. If the intent is ambiguous → **escalate immediately** (see above)
3. Once the contract is sufficiently aligned, finalize
4. If the server can be started, run immediately to get an explicit red
5. If the server does not exist, record as expected red
6. User confirms → read the contracts → write API implementation
7. Start server → run contracts
8. Red → fix the implementation first; only modify the contract if the failure reveals a self-contradiction
9. Green → contracts are verified, ready for CI

### Existing feature update flow

1. A behavior change is requested
2. Update contracts to reflect the new intent
3. Run contracts and accept the red
4. Update the implementation
5. Run again until green

## What NOT to do

- Do not write bare `contract.http("id", spec)` — always use `contract.http.with()` to create an instance first. Bare calls throw at runtime.
- Do not put `client` in the spec object — it belongs in `.with()`. Per-case `client` overrides are the only exception.
- Do not forget the `// @contract` marker above each exported contract
- Do not let an existing OpenAPI spec override the user's intent when defining a new contract
- Do read nearby OpenAPI/context/codebase conventions when they help align auth, error envelopes, naming patterns
- Do not use scattered `ctx.expect()` assertions — use `expect.schema` with Zod for response contracts
- Do not hardcode every response value — `description` explains intent, `expect.schema` defines shape, `verify` checks key values
- Do not treat `ECONNREFUSED` as a bug in contract-first mode — the server may not exist yet
- Do not invent auth, error codes, or business rules the user didn't describe — escalate instead
- Do not put contract-first artifacts in `explore/` or `tests/`
- Do not change `contract.flow()` syntax — flow contracts are not affected by the `.with()` API change
