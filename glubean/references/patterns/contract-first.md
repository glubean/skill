# Contract-First: Executable Contracts Before Implementation

## Why this pattern

**Problem:** AI agents jump from vague product intent straight to code implementation. Without an intermediate alignment step, the agent guesses too much — wrong status codes, invented field names, missing error cases, broken cross-endpoint contracts.

**Alternative:** write an OpenAPI spec first — but OpenAPI cannot express workflow contracts (data flowing between endpoints), and the spec-to-implementation gap still requires manual codegen or translation.

**This pattern:** write Glubean tests before the API exists. The tests define the executable contract — endpoint, request shape, response schema, status codes, error cases, and cross-endpoint data dependencies. AI reads these contracts to implement the API. The contracts remain the source of truth and are continuously verified.

## How it differs from test-after

| | Test-after | Contract-first |
|---|---|---|
| API state | Exists, callable | Does not exist or partially implemented |
| Information source | OpenAPI spec / context/ / traces | User intent + existing codebase conventions |
| Assertion purpose | Check behavior is correct | Define what behavior should be |
| Response contract | Inferred from traces or existing schema | Defined from intent, prefer Zod schema |
| Auth | Requires real credentials | Can use placeholders, but auth semantics still need user confirmation |
| Failure is normal? | No — fix needed | Yes — server not implemented yet |

## Directory convention

Contract-first artifacts go in `contracts/`, NOT in `explore/` or `tests/`.

```
contracts/   ← executable contract source of truth
explore/     ← free exploration, ad-hoc verification
tests/       ← stable regression for CI
```

Why separate:
- `contracts/` allows draft state, unresolved markers, alignment review, and projection — `explore/` and `tests/` do not have these semantics
- `contracts/` failure means "intent not aligned" or "implementation not done" — `tests/` failure means "stable behavior regressed"
- mixing them makes it impossible for the agent to know which files are truth (don't change) vs exploration (freely change)

Lifecycle: `contracts/` (define) → implementation → `tests/` (promote stable subset for regression)

When `product/` exists, the full flow is:

`product/` (intent) → `contracts/` (executable contract) → implementation → `tests/` (promoted regression)

## Start from `product/`

If the project has a `product/` directory, the agent should normally start there before drafting contracts.

The goal is not to write a giant PRD. The goal is to capture the minimum intent that lets contracts be written without guesswork.

Recommended minimal structure:

```text
product/
  _index.md
  features/
    ping.md
```

`product/_index.md` is not optional decoration. It is the navigation entry point the agent should read first as the feature set grows.

For a very small feature, one file per feature is enough, but the feature file should still be linked from `_index.md`.

Example:

```markdown
# Ping Endpoint

## Intent

Provide a minimal endpoint that confirms the service is alive.

## User-visible behavior

- A caller can send a ping request to the service.
- The service responds with `pong`.
- This endpoint is intended for health checks and smoke tests.

## Acceptance criteria

- The endpoint is reachable when the service is running.
- No auth is required.
- The response clearly indicates the service is healthy.

## Open questions

- Should the response be plain text or JSON?
- Should the path be `/ping` or `/health/ping`?

## Related contracts

- `contracts/system/ping.contract.test.ts`
```

What belongs in `product/`:

- intent
- user-visible behavior
- acceptance criteria
- business rules
- open questions

What does **not** belong in `product/`:

- exact request/response schema
- exact status codes
- exact auth header names
- implementation details

Those move into `contracts/` and into whatever implementation-side design source the project already uses.

Glubean does not need to own a `design/` directory. Architecture and ADR material should usually live with the implementation codebase, and `GLUBEAN.md` should point the agent there with `view ../...` references when needed.

Suggested `product/_index.md` shape:

```markdown
# Product Index

## Features

- [Ping Endpoint](features/ping.md)
```

Rule:

- When adding a new product feature file, update `product/_index.md` in the same change
- When reading product intent, start with `product/_index.md` when it exists

As the project grows, allow nested indexes, but keep a single global entry point:

```text
product/
  _index.md
  modules/
    issues/
      _index.md
      create.md
      list.md
      batch-delete.md
    auth/
      _index.md
      login.md
  shared/
    permissions.md
    errors.md
```

Rules for growth:

- `product/_index.md` remains the only global entry point
- module-level `_index.md` files are allowed as child navigation nodes
- every new product document must be reachable from some `_index.md`
- do not create orphan product files that are not linked from the index tree

Suggested scaling heuristics:

- small projects: `product/_index.md` + `product/features/*.md`
- when one domain accumulates several files, split it into `product/modules/<domain>/_index.md`
- when multiple features share the same business rule, move it into `product/shared/`
- when a new file is added, update the nearest relevant `_index.md` and keep the global `_index.md` pointing at the top-level modules or sections

## Updating an existing feature

Do not treat a behavior change as "just a small code edit". If the externally visible behavior changes, follow the same contract-first discipline.

Normal update sequence:

1. Update the relevant file in `product/` first
2. Update schema, types, and contract files to match the new intent
3. Run the contract and take the red result if the implementation is now behind the contract
4. Update the implementation
5. Run again until green

Examples that should follow the update flow:

- add a field to a response
- change an error code
- add a new query parameter
- tighten auth behavior
- change a workflow step or state dependency

Examples that usually do **not** require product updates:

- internal refactors with no user-visible behavior change
- storage changes
- queue/caching changes
- module layout changes

If in doubt, ask: **would a client, PM, QA reviewer, or API consumer describe this as changed behavior?** If yes, update `product/` first.

## Writing contract-first specs

Examples below inline schemas for brevity. In real projects, move reusable Zod schemas into `schemas/` and shared response types into `types/` so contracts stay readable and updates stay centralized.

Before writing contract files:

1. Read `product/_index.md` first when it exists.
2. Follow the index tree to the relevant module or feature file.
3. If it does not exist, create a minimal intent file first unless the user explicitly wants to skip that layer.
4. Update the relevant `_index.md` files when adding a new feature or module file.
5. Resolve obvious ambiguities before finalizing the contract.
6. Then choose the right contract scope.

Choose the right scope:

- **Single-endpoint contract**: one endpoint with one clear behavior
- **Resource contract set**: a new resource or a related group of endpoints such as CRUD + list/query
- **Workflow contract**: multi-step behavior spanning multiple endpoints or resources

If the user asks for a new resource rather than a single endpoint, do not jump straight into one file. First outline the resource contract set, then write the individual contracts.

### Single-endpoint contract

Define the full request/response contract. Use `ctx.validate(zodSchema)` for the response shape, not scattered field assertions:

```typescript
import { test } from "@glubean/sdk";
import { z } from "zod";

export const createUser = test(
  { id: "create-user", name: "Create user", tags: ["spec", "users"] },
  async (ctx) => {
    const res = await ctx.http.post("/users", {
      json: { name: "Alice", email: "alice@example.com" },
    });
    ctx.expect(res.status).toBe(201);
    const user = await res.json();
    ctx.validate(user, z.object({
      id: z.string(),
      name: z.string(),
      email: z.string().email(),
      createdAt: z.string().datetime(),
    }), "create user response");
    // Value assertions only for key business fields
    ctx.expect(user.name).toBe("Alice");
    ctx.expect(user.email).toBe("alice@example.com");
  },
);
```

Rules:
- `ctx.validate(zodSchema)` defines the response contract — field names, types, format constraints
- `ctx.expect` assertions for key business values only — don't hardcode every field
- Tag with `"spec"` to distinguish from verification tests
- Response type comes from intent, not from running the API
- In real projects, move reusable schemas to `schemas/` and reusable types to `types/` instead of keeping them inline in `contracts/`

### Resource contract set

When the user asks for a new resource, a CRUD surface, or a related API family, start by defining the contract inventory before writing files.

Typical resource contract inventory:

- create
- get by id
- update / patch
- delete
- list / search / filter / pagination
- auth / permission boundaries
- key error cases

For example, a new `labels` resource might start with:

```text
contracts/
  labels/
    create-label.contract.test.ts
    get-label.contract.test.ts
    update-label.contract.test.ts
    delete-label.contract.test.ts
    list-labels.contract.test.ts
    label-errors.contract.test.ts
```

Rules:

- Plan the full resource surface first, even if you only implement part of it now
- Keep one primary behavior per file; do not collapse unrelated endpoints into one contract
- Use separate files for list/query behavior and write operations when their semantics differ
- Use workflow contracts only when behavior depends on state flowing across endpoints
- If the user asks for "a new resource", clarify whether they want the full CRUD surface or a smaller subset

### Workflow contract

Use `.step()` chain to express cross-endpoint data dependencies:

```typescript
import { test } from "@glubean/sdk";
import { z } from "zod";

export const userRegistrationFlow = test("user-registration")
  .meta({ name: "User registration flow", tags: ["spec", "auth"] })
  .step("register", async (ctx) => {
    const res = await ctx.http.post("/auth/register", {
      json: { name: "Alice", email: "alice@example.com", password: "secure123" },
    });
    ctx.expect(res.status).toBe(201);
    const user = await res.json();
    ctx.validate(user, z.object({ id: z.string() }), "register response");
    return { userId: user.id };
  })
  .step("login", async (ctx, { userId }) => {
    const res = await ctx.http.post("/auth/login", {
      json: { email: "alice@example.com", password: "secure123" },
    });
    ctx.expect(res.status).toBe(200);
    const body = await res.json();
    ctx.validate(body, z.object({
      token: z.string(),
      userId: z.string(),
    }), "login response");
    ctx.expect(body.userId).toBe(userId);
    return { token: body.token, userId };
  })
  .step("get profile", async (ctx, { token, userId }) => {
    const res = await ctx.http.get(`/users/${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    ctx.expect(res.status).toBe(200);
    const profile = await res.json();
    ctx.validate(profile, z.object({
      name: z.string(),
      email: z.string().email(),
    }), "profile response");
    ctx.expect(profile.name).toBe("Alice");
  })
  .build();
```

Key points:
- Return state between steps = cross-endpoint data contract
- Step names = workflow stage documentation
- `ctx.validate` defines each step's schema contract; `ctx.expect` defines key business values
- The next step's input depends on the previous step's output — AI implementing this naturally gets the data flow right

### Error contract

Define expected error responses explicitly:

```typescript
export const createUserDuplicate = test(
  { id: "create-user-duplicate", name: "Duplicate email returns 409", tags: ["spec", "users", "error"] },
  async (ctx) => {
    const res = await ctx.http.post("/users", {
      json: { name: "Alice", email: "existing@example.com" },
      throwHttpErrors: false,
    });
    ctx.expect(res.status).toBe(409);
    const body = await res.json();
    ctx.validate(body, z.object({
      error: z.string(),
      code: z.literal("EMAIL_EXISTS"),
    }), "duplicate email error");
  },
);
```

## Escalation — the critical rule

**When the user's intent is ambiguous, contradictory, or missing necessary detail, the agent MUST stop and ask — not guess.**

This is the single most important behavior in contract-first mode. Without it, the agent is just generating tests from assumptions.

Examples of when to escalate:

- The user says "return the user" but doesn't specify which fields
- One part of the requirement says "return ID only", another says "return the full object"
- Auth strategy is mentioned but not specified (Bearer? API key? OAuth?)
- Error behavior is not described (what happens on duplicate? on not found?)
- The requirement mentions a workflow but doesn't specify the order of operations

When escalating:
1. Write what you understood as a draft contract
2. Mark the unresolved parts explicitly (e.g. `// UNRESOLVED: should this return full object or just id?`)
3. Present the conflict or ambiguity to the user
4. Wait for confirmation before finalizing the contract, running it, or proceeding to implementation when the ambiguity affects status codes, schema shape, auth, error semantics, or workflow order
5. Do NOT silently pick one interpretation and implement it

## Agent behavior

### New feature flow

1. User describes intent → draft Glubean contracts in `contracts/`
2. If the intent is ambiguous or contradictory in a way that affects externally visible behavior → **escalate immediately, do not finalize or run the contract yet** (see above)
3. Once the contract is sufficiently aligned, finalize the contract in `contracts/`
4. If the server can be started or the endpoint partially exists, run immediately to get an explicit red
5. If the server does not exist and cannot run, record this as **draft spec / expected red**
6. User confirms → read the contracts → write API implementation
7. Start server → run contracts via MCP
8. Red → fix the implementation first; only modify the contract if the failure reveals a self-contradiction in the spec
9. Green → promote stable contract subset to `tests/` for regression

### Existing feature update flow

1. A user-visible behavior change is requested
2. Update the relevant `product/` file first
3. Update schemas, types, and contracts to reflect the new intent
4. Run the contract and accept the red result if the implementation is now outdated
5. Update the implementation
6. Run again until green
7. If the change is stable and belongs in regression coverage, keep `tests/` aligned with the updated contract

## What NOT to do

- Do not let an existing OpenAPI spec or context file override the user's intent when defining a new contract
- Do read nearby OpenAPI/context/codebase conventions when they help you align auth semantics, error envelopes, naming patterns, or shared response shapes with the surrounding system
- Do not skip `ctx.validate(zodSchema)` — scattered field assertions are not a contract
- Do not hardcode every response value — distinguish "this is the contract" from "this is example data"
- Do not treat `ECONNREFUSED` as a bug in contract-first mode — the server may not exist yet
- Do not invent auth, error codes, or business rules the user didn't describe — escalate instead
- Do not put contract-first artifacts in `explore/` or `tests/` — they belong in `contracts/`
