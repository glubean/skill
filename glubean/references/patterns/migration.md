# Migration from Existing API Assets

## Why this pattern

**Problem:** users already have API assets (Postman, Apifox, OpenAPI, `.http`, cURL, legacy tests). Agents treat migration as format-conversion and generate shallow tests.
**Alternative:** directly translate requests into `ctx.http.*` calls — fast but preserves weak structure, guesses auth, and spreads mistakes.
**This pattern:** treat migration as a staged workflow. Read the project first, classify what converts safely, lock one representative pattern, then batch-convert.

## When to use

Any source that contains API request information can be migrated — the agent reads the source, extracts request intent, and writes Glubean tests. There is no format or language whitelist. Glubean supports HTTP, GraphQL (`@glubean/graphql`), and gRPC (`@glubean/grpc`). Common sources include Postman, Apifox, OpenAPI, `.http`/`.rest`, cURL, proto files, GraphQL schemas, and legacy test code in any language (Jest, pytest, Rust, Go, etc.).

Do not use for single endpoint smoke tests, small manual fixes, or contract-first work.

## Hard rules

1. Migration must happen inside a real Glubean project, not a scratch folder.
2. Read project context first: `package.json`, `GLUBEAN.md`, `tests/`, `explore/`, `types/`, `schemas/`, `config/`, existing auth helpers.
3. **Confirm auth before anything else.** See [Auth gate](#auth-gate) below.
4. Do not assume source assets are correct. Treat them as evidence, not truth.
5. For large migrations (20+ requests), plan first and generate second.

## Auth gate

Auth is the single most common migration failure. Source assets almost never describe auth correctly — Postman inherits from folders, Apifox uses global settings, OpenAPI `securitySchemes` rarely match runtime behavior, `.http` files hardcode expired tokens.

**Before writing any test code**, present the user with:

1. What auth evidence you found in the source assets (header names, token types, variable references)
2. Your best guess for the Glubean auth strategy (bearer, API key, OAuth, cookie, none)
3. Which secrets need to go in `.env.secrets` vs public config in `.env`
4. Whether `@glubean/auth` plugin is needed or plain `configure()` headers are enough

Wait for explicit confirmation. If the user says "just use what Postman has", push back — Postman env variables and pre-request scripts do not translate directly. Confirm the actual runtime auth flow.

See [auth.md](auth.md) and [configure.md](configure.md) for implementation patterns after confirmation.

## Source reliability

| Source | Reliable for | Weak for |
|---|---|---|
| Postman collection | paths, methods, bodies, headers, folder grouping | business intent, auth reasoning, data lifecycle |
| Apifox export | paths, schemas, example payloads, tags | runtime auth, script intent |
| OpenAPI / Swagger | operation grouping, request/response shape, status codes | real examples, undocumented business rules |
| `.http` / `.rest` / cURL | executable request examples | project-wide grouping, negative coverage |
| Proto files / gRPC stubs | service definitions, RPC methods, message shapes | runtime behavior, auth |
| GraphQL schemas / queries | type system, operation names, field structure | resolver behavior, auth |
| Legacy test code (any language) | workflow intent, custom assertions, setup semantics | direct portability |

## Workflow (5 phases)

### Phase 1 — Feasibility scan

Before writing code, produce a read-only report:

- Source inventory: what assets exist, format, size
- Current project structure and conventions
- Classification of each request/test into buckets (see below)
- Blockers and open questions (auth model, secrets, dynamic scripts)
- Proposed file layout and auth/secret mapping
- Which representative flow to migrate first

For each source item, identify: request identity, inputs, state needs (auth, setup, chaining), assertion depth, and risk level.

**Stop and present the scan report to the user. Do not proceed until the user approves the plan.** Suggest the user review the proposed file layout and classification before continuing.

### Phase 2 — Lock minimal project shape

Auth should already be confirmed from the [auth gate](#auth-gate). Lock the decisions that pollute everything if wrong — do not batch-convert without these:

- Shared `configure()` location and base URL → see [configure.md](configure.md)
- Public vars vs secrets naming
- File grouping: by resource, workflow, or tag

Leave assertion depth details, builder boundaries, naming conventions, and type/schema extraction for after the representative slice.

### Phase 3 — Representative slice

Build one slice that exercises real complexity against the minimal shape from Phase 2:

- Auth if the suite needs it
- At least one write + verify + cleanup
- Not the simplest endpoint — the one that tests whether the locked shape actually works

**Stop and let the user review the slice.** Suggest the user run the generated tests with the VSCode extension to verify they actually pass before approving. Do not batch-convert until the user confirms the slice works.

### Phase 4 — Freeze reusable style, then batch-convert

From the approved slice, freeze the remaining conventions:

- Assertion depth: status-only vs key fields vs schema
- When to use builder flows vs independent tests
- Teardown policy for write tests
- Naming conventions for test IDs
- When to extract to `types/` or `schemas/`

Then batch-convert incrementally:

- One Postman folder / Apifox tag / OpenAPI tag / legacy module at a time
- Do not migrate the whole source tree in one shot unless tiny

### Phase 5 — Run, fix, promote

- Run generated files, fix setup issues
- Replace weak assertions (status-only → key fields or schema)
- Extract shared types/schemas when reuse appears
- Move stable coverage into `tests/` — see [promotion.md](promotion.md)

## Classification buckets

Map each source item to a Glubean pattern:

| Signal | Glubean shape |
|---|---|
| One request, fixed input | `test(...)` |
| One endpoint, many query variations | `test.each(...)` |
| Create → read → update → delete | Builder workflow |
| Chained values between requests | Builder state passing |
| Repeated auth bootstrap | Shared `configure()` or auth helper |
| Reusable body/response shape | `types/` and `schemas/` extraction |

## Source-specific notes

**Postman:** Env variables → `ctx.vars.require(...)`, secrets → `ctx.secrets.require(...)`, chained values → builder state (not globals), `pm.test(...)` → `ctx.expect(...)`. Do not mechanically port `pm.*` helpers.

**Apifox:** Export as OpenAPI (for schemas) or Postman (for payloads), whichever is more complete. Trust project evidence over export when they conflict.

**OpenAPI:** Strong for planning (operationId → test ID, tags → file grouping, schemas → validation). Not enough alone for auth, setup, or business rules.

**`.http` / cURL:** Treat as request seeds. Improve assertion depth, merge duplicate setup into shared helpers.

**Legacy tests:** Keep scenario semantics, not the framework. `beforeAll` → shared setup or builder. Framework assertions → `ctx.expect(...)`. If old suite has business-critical assertions absent from spec, prefer it as truth.

## Decision points — stop and ask

Auth is handled by the [auth gate](#auth-gate) before any code. Beyond auth, also stop for:

- Pre-request scripts with signatures, encryption, or token refresh
- Dynamic values affecting later requests with no stable identifier
- Conflicting evidence between spec, collection, and live behavior
- Unclear grouping: independent tests vs end-to-end flows

## Common traps

1. **Treating exports as complete tests** — a collection entry proves a request existed, not that the assertion is good enough.
2. **Copying dynamic scripts blindly** — if behavior is not clearly understood, do not translate line by line.
3. **One big file per export** — group by resource or workflow, not by source file size.
4. **Keeping status-only assertions** — acceptable for first smoke pass, not for a migrated regression suite.
5. **Ignoring existing conventions** — if the repo has `configure.ts`, auth helpers, tags, schemas, reuse them.
