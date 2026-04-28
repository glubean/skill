# Attachment Model — Needs, Overlays, requireAttachment

The v10 way to write a contract case that depends on dynamic setup state (a token, a seeded record, a feature flag) without inlining lifecycle into the contract itself.

## Why this pattern

**Problem:** A contract case like "GET /me returns the caller's profile" needs an authenticated bearer token. Two failing alternatives:
1. **Inline setup in the case** — pollutes the contract with HOW (login flow), making it hard to reuse the case for replay, projection to OpenAPI, or running it with a different token source.
2. **Pre-acquire token in `session.ts` + `configure({{TOKEN}})`** — works for the "every contract uses one global token" case (see [session-auth.md](session-auth.md)), but doesn't compose for per-case setup, doesn't type-check what the case actually needs, and doesn't give you per-case cleanup.

**This pattern:** keep the contract case as **pure semantics** (`endpoint`, `expect`, `needs`, `given`). Lifecycle lives in a separate **overlay** (`contract.bootstrap`) registered in a `*.bootstrap.ts` sibling. The runner connects the two at execution time. Each side stays single-purpose.

## Three building blocks

### 1. `defineHttpCase<Needs>` — declare Needs at the case site

Inside a contract literal, TypeScript can't correlate `needs: SchemaLike<X>` and `body: (input: Y) => ...` from sibling fields. The factory captures `Needs` once via the explicit generic, so all action fields are checked against `(input: Needs) => ...`:

```typescript
import { defineHttpCase } from "@glubean/sdk";
import { z } from "zod/v4";

const ProfileSchema = z.object({
  id: z.number(),
  username: z.string(),
  email: z.string(),
});

const authorized = defineHttpCase<{ token: string }>({
  description: "Valid bearer token returns the caller's profile",
  needs: z.object({ token: z.string() }),
  // headers, body, params, query are now functions of `Needs`
  headers: ({ token }) => ({ Authorization: `Bearer ${token}` }),
  expect: { status: 200, schema: ProfileSchema },
});
```

Key points:
- The `<{ token: string }>` generic is the case's **logical input type**. Type-locked: a typo in `headers: ({ tkoen }) => ...` is a compile error, not a runtime surprise.
- `needs` is the runtime schema for the same shape — used by the runner to validate input from overlays or `--input-json`.
- Function-valued action fields (`headers`, `body`, `params`, `query`) take `Needs` as their parameter and produce the wire shape.
- `defineHttpCase` returns a normal case object — assign it to a `const` and reference it in the contract.

**HTTP only.** `defineHttpCase` is the only `defineXCase<Needs>` factory shipped today — gRPC and GraphQL contracts can declare `needs` directly on their case literal, and rely on per-protocol type inference. The factory pattern may extend to gRPC / GraphQL in a future release.

### 2. Shorthand cases — reference defined cases inside the contract

Once cases are bound as `const` outside the contract, plug them into the `cases` block via shorthand property syntax:

```typescript
import { contract } from "@glubean/sdk";
import { dummyApi } from "../../config/dummyjson-api.ts";

const dummyjson = contract.http.with("dummyjson-attachment-model", {
  client: dummyApi,
  security: "bearer",
});

const authorized = defineHttpCase<{ token: string }>({ /* ... */ });

const requiresAttachment = defineHttpCase<{ token: string }>({
  description: "needs declared AND requireAttachment: true → bare run blocked",
  needs: z.object({ token: z.string() }),
  headers: ({ token }) => ({ Authorization: `Bearer ${token}` }),
  expect: { status: 200, schema: ProfileSchema },
  runnability: { requireAttachment: true },  // see §6.3 below
});

// @contract
export const getMe = dummyjson("auth.me", {
  endpoint: "GET /auth/me",
  feature: "Authentication (v10 attachment model)",
  description: "Return the authenticated user's profile via overlay-supplied token",
  cases: {
    authorized,           // ← shorthand reference, not inline literal
    requiresAttachment,
  },
});
```

The contract itself stays declarative — no logic, no functions inside the cases block. Each case is fully defined at its `const` site and reused by name.

### 3. `contract.bootstrap()` — the overlay

Setup/cleanup lives in a sibling `*.bootstrap.ts` file. The harness eagerly loads every `*.bootstrap.ts` in the project before discovery (§7.4) — colocation is the convention but the file can live anywhere as long as it's reachable.

```typescript
// me.bootstrap.ts (sibling of me.contract.ts)
import { contract } from "@glubean/sdk";
import { getMe } from "./me.contract.ts";

// Plain-function form: setup + cleanup, returns the input the case needs.
export const meAuthorizedOverlay = contract.bootstrap(
  getMe.case("authorized"),
  async (ctx) => {
    // ... do the login flow, seed test data, whatever ...
    const res = await ctx.http.post(
      "https://dummyjson.com/auth/login",
      { json: { username: "emilys", password: "emilyspass" } },
    ).json<{ accessToken: string }>();

    ctx.cleanup(async () => {
      // optional cleanup, runs LIFO after the case completes
      // (logout, delete fixtures, restore feature flag, etc.)
    });

    return { token: res.accessToken };  // MUST satisfy case's `needs` shape
  },
);
```

What the overlay does:
- The first argument is a case reference (`contractVar.case("caseKey")`) — type-checked.
- The second argument is either a plain async function or a structured `{ params, run }` object (see "Bootstrap params" below).
- The function's return value MUST satisfy the case's `needs` schema. The runtime validates after `run()` returns, before passing to the case's action fields.
- `ctx.cleanup(fn)` registers cleanup callbacks that run in LIFO order after the case completes (success or failure).
- One overlay per testId. Two overlays for the same case is a load-time error.

### 4. Structured form — `params` for parametric overlays

When the overlay should accept input from outside (e.g. a different account per run, a feature flag from CI), use the structured form:

```typescript
import { z } from "zod/v4";

export const meAttachOverlay = contract.bootstrap(
  getMe.case("requiresAttachment"),
  {
    params: z.object({
      username: z.string(),
      password: z.string(),
    }),
    run: async (ctx, { username, password }) => {
      const res = await ctx.http.post(
        "https://dummyjson.com/auth/login",
        { json: { username, password } },
      ).json<{ accessToken: string }>();

      ctx.cleanup(async () => { /* ... */ });
      return { token: res.accessToken };
    },
  },
);
```

Now you can pass params from the CLI:
```bash
glubean run me.contract.ts --filter auth.me.requiresAttachment \
  --bootstrap-json '{"username":"{{TEST_USER}}","password":"{{TEST_PASS}}"}'
```

Or programmatically:
```typescript
import { runCase } from "@glubean/runner";
await runCase({
  filePath: "me.contract.ts",
  testId: "auth.me.requiresAttachment",
  sharedConfig: { /* ... */ },
  bootstrapInput: { username: "test1", password: "secret1" },
});
```

`{{VAR}}` interpolation against env vars + secrets happens at the CLI/MCP/runCase surface boundary, before schema validation. See [runner-input.md](runner-input.md).

## §6.3 — when bare runs are allowed vs blocked

The case's `needs` declaration and `runnability.requireAttachment` flag combine to gate bare runs:

| Case shape | Bare run | `--input-json` | Overlay registered | Flow `.step()` |
|---|---|---|---|---|
| no `needs`, no `requireAttachment` | ✅ | meaningless (no needs to satisfy) | ✅ | ✅ |
| `needs` declared, no `requireAttachment` | ❌ | ✅ rawBypass | ✅ | ✅ |
| `needs` + `runnability.requireAttachment: true` | ❌ | ✅ rawBypass | ✅ | ✅ |
| no `needs` + `runnability.requireAttachment: true` | ❌ | ❌ meaningless | ✅ | ✅ |

The two `requireAttachment` rows differ in whether `--input-json` is meaningful:
- With `needs` → input shape is defined → `--input-json` is a valid alternative to overlay.
- Without `needs` → no input shape to satisfy → `--input-json` is meaningless; only an overlay can run the case. Use `--force-standalone` for debug-only bypass (emits a runtime warning).

When a bare run hits a blocked case, the runner **hard-errors** — no silent skip, no fall-through to a dummy run.

## §5.1 — dispatch decision tree

When the runner reaches a case, it picks one of five paths:

```
1. Explicit input present (--input-json / runCase({ input })) →
   validate input against `needs` → run case with that input.
   Overlay is NEVER invoked. (§5.1 step 1)

2. requireAttachment + no overlay → hard error.
   (UNLESS --force-standalone is set, then warn + fall to step 5.)

3. Overlay registered → run overlay (with bootstrap-json params if
   structured form) → validate output against `needs` → run case
   with overlay's output. Overlay cleanup runs LIFO. (§5.1 step 3)

4. `needs` declared, no overlay, no input → hard error. (§5.1 step 4)

5. No needs, no overlay → run case bare. (§5.1 step 5)
```

Invariants enforced at runtime:
- Explicit input always wins over overlay (step 1 before step 3).
- `--input-json` + `--bootstrap-json` together is rejected at every surface (CLI / MCP / runCase).
- bootstrap-json supplied with no overlay → hard error (no silent drop).
- bootstrap-json supplied to plain-function overlay → hard error (the function takes no params).

## Canonical project structure

```
contracts/
  attachment-model/
    me.contract.ts          ← defineHttpCase<Needs>(...) + shorthand cases
    me.bootstrap.ts         ← contract.bootstrap(getMe.case("authorized"), ...)
```

Naming convention: `<thing>.bootstrap.ts` lives next to `<thing>.contract.ts`. The harness loads every `*.bootstrap.ts` in the project at startup (§7.4), so the file location is more about author convenience than discovery. Colocation is recommended for review.

A real cookbook example: [cookbook/contract-first/contracts/attachment-model/](https://github.com/glubean/cookbook/tree/main/contract-first/contracts/attachment-model).

## When to use this pattern vs alternatives

| Situation | Use |
|---|---|
| Single global token, all contracts use it | `session.ts` + `configure({{TOKEN}})` — see [session-auth.md](session-auth.md) |
| Per-case setup with structured Needs (login + cleanup, seeded record + delete) | `defineHttpCase<Needs>` + `contract.bootstrap()` — this pattern |
| Mix: global token for most cases, custom setup for a few | Both coexist — session.ts for default, overlay for special cases |
| Setup the case but skip the overlay for one-off replay | `--input-json '<JSON>'` — see [runner-input.md](runner-input.md) |
| Spec-verify the contract without setup at all | `--force-standalone` — debug bypass |

## Common mistakes

- **Inlining cases inside the contract literal when they have `needs`.** TypeScript can't correlate the schema and the function-valued fields across sibling object keys. Always use `defineHttpCase<Needs>`.
- **Putting setup logic in the contract case itself.** `cases.authorized.fn = async (ctx) => { /* login here */ }` — wrong. The case is pure semantics. Setup goes in `contract.bootstrap()`.
- **Forgetting the `*.bootstrap.ts` file extension.** Files without that exact suffix aren't eagerly loaded by the harness. Naming an overlay file `me-bootstrap.ts` (with a dash) silently breaks discovery — overlays in it never fire.
- **Two overlays for the same testId.** Load-time error — first wins, second emits a structured error. Either consolidate or separate them by case.
- **Returning the wrong shape from overlay `run()`.** Runtime validates against `needs` and hard-errors. The TypeScript generic on `defineHttpCase<Needs>` flows through `getMe.case("authorized")` so the overlay return type is checked at compile time.
- **Mixing `--input-json` and `--bootstrap-json`.** Surface boundary rejects the combination. Pick one channel.
- **Treating `runnability.requireAttachment` as a soft hint.** It's a hard gate. A case marked `requireAttachment` cannot be bare-run without `--force-standalone` (and that's debug-only).

## Cross-references

- [runner-input.md](runner-input.md) — `--input-json`, `--bootstrap-json`, `--force-standalone` CLI channels.
- [session-auth.md](session-auth.md) — global token via session.ts (alternative to overlays for single-token projects).
- [case-execution.md](case-execution.md) — `requires` / `defaultRun` / `runnability` distinctions.
- [contract-first.md](contract-first.md) — full contract authoring workflow.
