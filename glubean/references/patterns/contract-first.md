# Contract-First: Executable Contracts Before Implementation

## Why this pattern

**Problem:** AI agents jump from vague product intent straight to code implementation. Without an intermediate alignment step, the agent guesses too much — wrong status codes, invented field names, missing error cases, broken cross-endpoint contracts.

**Alternative:** write an OpenAPI spec first — but OpenAPI cannot express workflow contracts (data flowing between endpoints), and the spec-to-implementation gap still requires manual codegen or translation.

**This pattern:** write `contract.http()` declarations before the API exists. Each contract defines endpoint, request shape, response schema, status codes, error cases, and auth boundaries as structured, executable cases. AI reads these contracts to implement the API. The contracts remain the source of truth and are continuously verified.

## How it differs from test-after

| | Test-after | Contract-first |
|---|---|---|
| API state | Exists, callable | Does not exist or partially implemented |
| Information source | OpenAPI spec / context/ / traces | User intent + existing codebase conventions |
| API | `test()` — imperative, free-form | `contract.http()` — declarative, structured |
| Response contract | Inferred from traces or existing schema | Defined from intent, prefer Zod schema |
| Auth | Requires real credentials | Can use placeholders, but auth semantics still need user confirmation |
| Failure is normal? | No — fix needed | Yes — server not implemented yet |

## Directory convention

```
schemas/     ← Zod response schemas
contracts/   ← contract.http() specs + contract.flow() verification
tests/       ← test() for cases contract can't express (browser, polling)
explore/     ← free exploration, ad-hoc verification
```

Why separate:
- `contracts/` failure means "intent not aligned" or "implementation not done" — `tests/` failure means "stable behavior regressed"
- `contract.http()` produces `Test[]` directly — runner executes them without promotion
- mixing contract specs and ad-hoc tests makes it impossible to generate projection/coverage reports

Lifecycle: `contracts/` (define) → implementation → run contracts until green

`contract.http()` produces standard `Test[]`, so `glubean run contracts` works out of the box.

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
2. **Auth** — which client (API key? public? specific role?)? Is the answer "I don't know" acceptable or blocking?
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

### Single-endpoint contract

Use `contract.http()` with `cases`. Each case must have a `description` explaining why it exists:

```typescript
import { contract } from "@glubean/sdk";
import { z } from "zod/v4";

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email(),
  createdAt: z.string().datetime(),
});

export const createUser = contract.http("create-user", {
  endpoint: "POST /users",
  description: "Create a new user account.",
  client: api,
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
      client: publicHttp,
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

Rules:
- Each case has a required `description` — explains the business logic or boundary
- `expect.schema` validates response shape via Zod (or any SchemaLike)
- `verify` callback runs after schema validation for business-logic assertions
- `deferred` marks cases that can't run yet (missing credentials, infrastructure)
- `client` per case allows testing different auth contexts
- In real projects, move Zod schemas to `schemas/`

### Resource contract set

When the user asks for a new resource, plan the full surface first:

```text
contracts/
  users/
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
- Each endpoint should also have its own `contract.http()` for spec cases

### Error contract

Define expected error responses explicitly:

```typescript
export const createUserDuplicate = contract.http("create-user-errors", {
  endpoint: "POST /users",
  description: "Error cases for user creation.",
  client: api,
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

When escalating:
1. Write what you understood as a draft contract
2. Mark unresolved parts with `deferred` or comments
3. Present the conflict or ambiguity to the user
4. Wait for confirmation before finalizing

## Agent behavior

### New feature flow

1. User describes intent → draft `contract.http()` in `contracts/`
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

- Do not let an existing OpenAPI spec override the user's intent when defining a new contract
- Do read nearby OpenAPI/context/codebase conventions when they help align auth, error envelopes, naming patterns
- Do not use scattered `ctx.expect()` assertions — use `expect.schema` with Zod for response contracts
- Do not hardcode every response value — `description` explains intent, `expect.schema` defines shape, `verify` checks key values
- Do not treat `ECONNREFUSED` as a bug in contract-first mode — the server may not exist yet
- Do not invent auth, error codes, or business rules the user didn't describe — escalate instead
- Do not put contract-first artifacts in `explore/` or `tests/`
