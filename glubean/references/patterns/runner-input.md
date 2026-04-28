# Runner Input Channels — `--input-json`, `--bootstrap-json`, `--force-standalone`

CLI / MCP / `runCase()` channels for feeding input to a contract case at runtime, bypassing or driving the overlay.

## When to use this pattern

You need this when the **default overlay-driven** case execution isn't what you want for a particular run:

- **Replay a case** with input from a prior run (logged, copied, or computed elsewhere) — `--input-json`.
- **Parametrize an overlay** with values from CI / env / config (different account per environment, feature flag value, tenant ID) — `--bootstrap-json`.
- **Spec-verify a case** against a server without running setup — `--force-standalone`.

If you don't have a specific reason for one of those, you don't need this pattern — the overlay handles things automatically.

Companion pattern: [attachment-model.md](attachment-model.md) for `defineHttpCase<Needs>` / `contract.bootstrap()` / `requireAttachment`.

## The three channels

| Channel | Purpose | Surface form |
|---|---|---|
| **explicit input** | Run a case with this input directly. Overlay is bypassed entirely. | `--input-json '<JSON>'` |
| **bootstrap input** | Pass params to the overlay's `run(ctx, params)`. Overlay still runs. | `--bootstrap-json '<JSON>'` |
| **force-standalone** | Debug bypass for `runnability.requireAttachment` on no-needs cases. Emits a runtime warning. | `--force-standalone` |

All three are testId-scoped. Use `--filter <testId>` to pick exactly one case per run when supplying any of these flags.

## `--input-json` — explicit input bypass

You already have the input. Skip the overlay; run the case with this input directly.

```bash
# Case shape (with needs):
#   const authorized = defineHttpCase<{ token: string }>({
#     needs: z.object({ token: z.string() }),
#     headers: ({ token }) => ({ Authorization: `Bearer ${token}` }),
#     ...
#   });

# Run with explicit token, overlay never invoked:
glubean run me.contract.ts \
  --filter auth.me.authorized \
  --input-json '{"token":"eyJhbGciOi..."}'
```

What happens:
1. Surface (CLI) parses the JSON.
2. `{{VAR}}` interpolation against `{ ...vars, ...secrets, ...process.env }` is applied at the surface boundary, BEFORE schema validation.
3. The runtime validates the parsed input against the case's `needs` schema. Mismatch → hard error.
4. The case's action fields (`headers`, `body`, ...) receive this input.
5. Overlay is never invoked. No setup, no cleanup.

When to reach for this:
- Replaying a failed run with the exact input it received (debug).
- Driving a case from an external orchestrator that already produced the input.
- CI gating: spec-check the case against a known input without re-running expensive setup.

When NOT to reach for this:
- Initial development of a contract case — let the overlay run.
- "Running it manually one time" — overlay handles it; you don't need to hand-craft the input.

## `--bootstrap-json` — overlay parameters

Your overlay is in **structured form** (`{ params, run }`), and you want to pass it different params for this run.

```typescript
// In me.bootstrap.ts:
export const meAttachOverlay = contract.bootstrap(
  getMe.case("requiresAttachment"),
  {
    params: z.object({
      username: z.string(),
      password: z.string(),
    }),
    run: async (ctx, { username, password }) => {
      const res = await ctx.http.post(/*...login.../*/).json<...>();
      ctx.cleanup(/* ... */);
      return { token: res.accessToken };
    },
  },
);
```

Run with custom params:
```bash
glubean run me.contract.ts \
  --filter auth.me.requiresAttachment \
  --bootstrap-json '{"username":"{{TEST_USER}}","password":"{{TEST_PASS}}"}'
```

What happens:
1. Surface parses + interpolates `{{VAR}}` against env/vars/secrets.
2. Params validated against the overlay's `params` schema.
3. Overlay's `run(ctx, params)` is invoked with the validated params.
4. Overlay produces case input (validated against case's `needs`).
5. Case runs with that input.

Important: `--bootstrap-json` REQUIRES the overlay to be in structured form (`{ params, run }`). Passing it to a plain-function overlay (`contract.bootstrap(ref, async (ctx) => ...)`) is a hard error — the function takes no params, the runtime won't silently drop the input.

## `--force-standalone` — debug bypass

A case marked `runnability: { requireAttachment: true }` cannot be bare-run by default — the runner hard-errors. `--force-standalone` is the debug-only escape hatch.

```bash
# Cases with no needs (overlay-only behavior, no input shape):
glubean run me.contract.ts \
  --filter auth.me.requiresAttachment \
  --force-standalone
```

What happens:
1. The dispatcher's §5.1 step 2 (`requireAttachment + no overlay → hard error`) is skipped for this testId.
2. Falls to step 5: case runs bare.
3. Runtime emits a `console.warn` so you don't forget the bypass is on.

Use cases:
- Spec-verifying that the contract endpoint at least returns the right HTTP status without setup (smoke against a mocked server).
- Debugging a specific case path when the overlay itself is broken.
- Quick wire-format check: does the request URL resolve correctly?

DO NOT use `--force-standalone` in CI or as a way to "make the test pass". It's an interactive debug tool. The runtime warning is intentional friction.

## Mutual exclusivity

`--input-json` and `--bootstrap-json` are **mutually exclusive** at every surface:

```bash
# ❌ Hard error at CLI boundary, run never starts:
glubean run me.contract.ts --filter X \
  --input-json '{"token":"a"}' \
  --bootstrap-json '{"username":"b"}'
```

The reason: `--input-json` skips the overlay (§5.1 step 1), so the bootstrap params would be silently ignored. Rather than drop them silently, the surface rejects the combination.

Same rule applies to `runCase({ input, bootstrapInput })` — the runner throws.

`--force-standalone` is independent — it can combine with neither, either, or both being absent.

## `{{VAR}}` interpolation rules

`{{VAR}}` placeholders inside `--input-json` / `--bootstrap-json` are interpolated at the surface boundary (CLI / MCP / `runCase`) BEFORE the values are serialized into env vars and shipped to the harness. Same rule for explicit input and bootstrap input.

**Substitution sources merge in this order — later wins:**

1. Project `vars` (from `.env`)
2. Project `secrets` (from `.env.secrets`)
3. `process.env`

So `process.env` wins over `.env.secrets` wins over `.env`. This matches the resolution order used elsewhere in the runner. If you have `TENANT_ID` in both `.env` (`acme`) and the shell (`shell-override`), `{{TENANT_ID}}` resolves to `shell-override`.

```bash
# Pull from .env / .env.secrets:
glubean run me.contract.ts \
  --filter X \
  --bootstrap-json '{"username":"{{TEST_USER}}","tenant":"{{TENANT_ID}}"}'

# Direct env-var pass-through (process.env wins):
TENANT_ID=acme-staging glubean run me.contract.ts \
  --filter X \
  --bootstrap-json '{"tenant":"{{TENANT_ID}}"}'
```

**Missing placeholders throw — they are NOT pass-through.** A `{{NOT_DEFINED_ANYWHERE}}` in your input fails at the surface boundary with `Error: Templating: missing env var "NOT_DEFINED_ANYWHERE"` BEFORE the harness spawns and BEFORE schema validation. Debug at the templating layer (check `.env`, `.env.secrets`, shell env), not at the JSON / schema layer.

## File-based JSON (`@path/to.json`)

For input that's awkward at the command line (multi-line, large), put it in a file and reference with `@`:

```bash
glubean run me.contract.ts \
  --filter X \
  --input-json '@fixtures/auth-input.json'
```

**Order: read → `JSON.parse(text)` → `applyEnvTemplating(parsed, env)`** — interpolation runs on the **parsed value**, not the raw text. Practical implication: `{{KEY}}` placeholders must sit inside JSON string values (e.g. `"token": "{{AUTH_TOKEN}}"`), not as bare/unquoted tokens or as JSON keys. The parser sees the literal `{{AUTH_TOKEN}}` string first; templating substitutes the value of that string after parse. This means you can't use `{{KEY}}` to inject a number/boolean/object directly — write it as a string and the schema layer will validate (or coerce) the post-templated value.

## Programmatic equivalents

The same three channels exposed via `runCase()`:

```typescript
import { runCase } from "@glubean/runner";

// Explicit input:
await runCase({
  filePath: "me.contract.ts",
  testId: "auth.me.authorized",
  sharedConfig: { /* ... */ },
  input: { token: "eyJ..." },
});

// Bootstrap params:
await runCase({
  filePath: "me.contract.ts",
  testId: "auth.me.requiresAttachment",
  sharedConfig: { /* ... */ },
  bootstrapInput: { username: "test1", password: "secret1" },
});

// Force standalone:
await runCase({
  filePath: "me.contract.ts",
  testId: "auth.me.requiresAttachment",
  sharedConfig: { /* ... */ },
  forceStandalone: true,
});
```

`runCase` applies `{{VAR}}` templating to both `input` and `bootstrapInput` before serializing to the harness — same behavior as CLI / MCP. The templating env defaults to `{ ...vars, ...secrets, ...process.env }` (process.env wins), built from the project's `.env` / `.env.secrets` loaded at the file's `rootDir`. To override, pass `templatingEnv: { /* explicit map */ }` in the options:

```typescript
await runCase({
  filePath: "me.contract.ts",
  testId: "auth.me.authorized",
  sharedConfig: { /* ... */ },
  input: { token: "{{AUTH_TOKEN}}" },
  // Override templating env (otherwise built from project .env + process.env):
  templatingEnv: { AUTH_TOKEN: "fixture-token-1" },
});
```

Missing-var throws apply: a `{{KEY}}` in `input` / `bootstrapInput` that doesn't resolve raises `Error: Templating: missing env var "KEY"` from `runCase` before the harness spawns. `runCase` enforces the same mutual exclusivity (`input` + `bootstrapInput` → throws).

## MCP equivalents

The MCP `glubean_run_local_file` tool exposes `inputJson`, `bootstrapInput`, and `forceStandalone` arguments mirroring the CLI flags. Same mutual-exclusivity and templating rules.

## Wire format (for harness-internal debugging)

Surfaces serialize input maps to env vars before spawning the harness. All three are JSON-encoded:

```
GLUBEAN_RUNNER_EXPLICIT_INPUT_MAP={"<testId>":<jsonValue>,...}
GLUBEAN_RUNNER_BOOTSTRAP_INPUT_MAP={"<testId>":<jsonValue>,...}
GLUBEAN_RUNNER_FORCE_STANDALONE_IDS=["<testId>","<testId>",...]
```

Note `GLUBEAN_RUNNER_FORCE_STANDALONE_IDS` is a JSON-encoded **string array**, NOT a comma-separated list — the harness `JSON.parse`s it.

The harness reads these env vars, populates the SDK's `runner-input-channel` storage, and then loads the user module. You don't write these env vars by hand — let the surface (CLI / MCP / `runCase`) do it. Documented here only for harness-internal debugging when an input doesn't reach a case as expected.

## Common mistakes

- **Forgetting `--filter <testId>`** — these flags require a single-test scope. A multi-match filter that resolves to >1 testIds is rejected at the surface.
- **Using `--input-json` when you should use `--bootstrap-json`** — if the overlay should run with custom params, use `--bootstrap-json`. `--input-json` skips the overlay.
- **Leaving `--force-standalone` in CI scripts** — it's debug-only; the runtime warning is there for a reason.
- **Mixing `--input-json` + `--bootstrap-json`** — surface rejects.
- **Quoting issues with shell-escaped JSON** — use `'...'` (single quotes) for the JSON value, not `"..."`. For complex JSON, use `@file.json`.
- **Forgetting that `runCase` DOES apply `{{VAR}}` templating by default** — same behavior as CLI / MCP. The default templating env is `{ ...vars, ...secrets, ...process.env }` (process.env wins) built from the project's `.env` / `.env.secrets`. If you want explicit control over what `{{KEY}}` resolves to (e.g. test fixtures, isolating from the developer's shell env), pass `templatingEnv` in the options. A typo'd `{{KEY}}` throws `Error: Templating: missing env var "KEY"` BEFORE the harness spawns — debug at the templating layer first.

## Cross-references

- [attachment-model.md](attachment-model.md) — the contract-side mechanics: `defineHttpCase<Needs>`, `contract.bootstrap()`, §5.1 dispatch, §6.3 runnability.
- [session-auth.md](session-auth.md) — global token alternative for projects where every contract uses one shared token.
