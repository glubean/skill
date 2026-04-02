# Context Setup — Giving the Agent API Knowledge

## Why this matters

**Problem:** without API reference material, the agent guesses endpoint paths, request bodies, and response shapes — then fails on the first run and wastes cycles fixing wrong assumptions.
**Alternative:** let the agent discover the API by running tests with `includeTraces: true` — this works but is slow (one round-trip per endpoint) and misses endpoints the agent doesn't know to try.
**This pattern:** put API reference material in `context/` so the agent reads it before writing tests. One read of the spec replaces multiple trial-and-error run cycles.

## Options (best to good)

### 1. OpenAPI spec (best for structured APIs)

Drop your OpenAPI/Swagger spec into `context/`:

```
context/
  openapi.json          # or openapi.yaml
```

For large specs, use the CLI to split into per-endpoint files that fit the agent's context window:

```bash
npx glubean@latest spec split context/openapi.json
```

This creates:

```
context/
  openapi.json
  openapi-endpoints/
    _index.md           # endpoint listing with method + path + summary
    GET_users.md        # dereferenced, self-contained endpoint doc
    POST_users.md
    GET_users_{id}.md
    ...
```

The agent reads `_index.md` first, then only the endpoints it needs. That makes endpoint selection more reliable and keeps context usage lower, leaving more room for business logic, source code notes, and existing test coverage.

If the user already has `context/openapi.json` or `.yaml` but has not split it yet, proactively suggest running `glubean spec split` or `npx glubean@latest spec split`. This is a convenience and quality hint, not a prerequisite, and it also saves context tokens for other high-value information.

### Patching incomplete specs

If the spec is missing fields, wrong, or auto-generated with gaps, create a `.patch.yaml` overlay instead of editing the spec directly:

```yaml
# context/openapi.patch.yaml
paths:
  /users:
    post:
      x-glubean-notes: "Requires admin role. Returns 403 for non-admin tokens."
      requestBody:
        content:
          application/json:
            schema:
              required: [email, role]
```

Apply it:

```bash
npx glubean@latest patch context/openapi.json
```

This produces a merged spec without modifying the original — so you can re-import from source and re-patch.

### 2. Source code side-by-side (best for internal APIs)

When you are testing your own API and the source code is in the same repo or accessible locally, point the agent at the route handlers directly:

```
context/
  routes/
    _index.md           # "Routes are in ../src/routes/ — read the handler for each endpoint"
```

Or in `GLUBEAN.md`:

```markdown
## API Reference
Route handlers are in `src/routes/`. Read the handler file before writing a test.
Auth middleware is in `src/middleware/auth.ts`.

## Product References
- view ../product/requirements.md
- view ../backend/src/routes/users.ts
- view ../backend/src/middleware/auth.ts
```

The agent reads the actual implementation — no spec drift, no missing fields.

### 3. Markdown docs (best for third-party APIs without specs)

When there is no OpenAPI spec and the API docs are only on a website, create concise markdown reference files:

```
context/
  api-reference.md      # or split by domain:
  users-api.md
  billing-api.md
```

The format is up to the user — the key is to include request body shape, response body shape, and error codes. Skip prose descriptions the agent doesn't need.

### 4. Product / business logic in GLUBEAN.md (improves all other options)

API specs and source code describe **what the API does**. Product logic describes **why it does it and what the rules are**. This is the most impactful context for test quality — and the one most often missing.

Suggest the user add a `## Business Rules` section to `GLUBEAN.md`:

```markdown
## Business Rules

- Only admins can create or delete users. Non-admin returns 403.
- Email must be unique across the organization. Duplicate returns 409.
- Projects in "archived" state cannot be updated or deleted. Returns 422.
- Free-tier accounts are limited to 5 projects. 6th create returns 402 with upgrade link.
- Deleting a user soft-deletes (sets deletedAt) — GET still works but list excludes them.
- Webhook URLs must be HTTPS. HTTP URLs return 422.

## State Machine: Project Lifecycle

draft → active → archived
- draft: can edit, cannot run tests
- active: can edit, can run tests, can archive
- archived: read-only, can unarchive back to active

## Roles

| Role | Create | Read | Update | Delete |
|------|--------|------|--------|--------|
| admin | yes | yes | yes | yes |
| member | yes | own | own | no |
| viewer | no | yes | no | no |

## Product References
- view ../product/requirements.md
- view ../backend/src/routes/projects.ts
```

This kind of context turns generic CRUD tests into tests that cover permission boundaries, state transitions, and business edge cases — the bugs that actually reach production.

**Even a few sentences help.** The difference between "I know the API shape" and "I know the API shape + the business rules" is the difference between surface tests and tests that catch real bugs. Reuse the same `Product References` pattern shown above; do not invent a second format.

### 5. Thin or missing context (fallback)

If you have little or no context, the agent should remind the user that adding context would improve the tests, but should not stop only for that reason.

If the minimum runnable facts are already known, such as a base URL, at least one endpoint, and enough auth evidence to make a request:

1. Write a smoke test with `includeTraces: true`
2. Read `responseSchema` from the trace to learn the response shape
3. Write real assertions based on what the API actually returns

This is the discovery-by-running approach. It works, but costs one MCP round-trip per endpoint.

If even those minimum facts are missing, the agent should say exactly what is missing and ask only for that minimum. Do not turn "please add richer context" into a hard prerequisite for continuing.

## Decision table

| Situation | Recommended approach |
|---|---|
| You have an OpenAPI spec | Drop in `context/`, run `spec split` for large specs |
| Spec is incomplete or wrong | Add `.patch.yaml`, run `patch` |
| Testing your own API (source available) | Point at source code in `GLUBEAN.md` |
| Third-party API, no spec | Write markdown docs in `context/` |
| Want deeper coverage on any of the above | Add business rules or `view ../...` pointers to `GLUBEAN.md` |
| Minimal runnable facts available, but little context | Discovery by running with traces |
| No endpoint/base URL/auth evidence at all | Ask only for the missing minimum, and suggest adding richer context in `GLUBEAN.md` |

## Context completeness levels

| Level | What the agent has | Test quality |
|---|---|---|
| **Spec only** | Endpoint paths, request/response shapes | Smoke + basic CRUD — covers the happy path |
| **Spec + source code** | Above + validation rules, middleware, DB constraints | Above + input validation, error boundaries |
| **Spec + source + product logic** | Above + business rules, roles, state machines | Above + permission tests, state transition tests, edge cases |
| **Minimal runnable facts only** | Base URL, at least one endpoint, and enough auth evidence to make a request | Smoke-first discovery — shallow until the agent learns more |

When context is at level 1 (spec only), proactively suggest the user add business rules or `view ../...` pointers in `GLUBEAN.md`. See [test-planning.md — Context quality check](test-planning.md).

## Agent behavior

When writing tests for an endpoint:

1. Check `context/` first — read `_index.md` or the relevant endpoint file
2. Check `GLUBEAN.md` for API reference pointers and business rules
3. If `GLUBEAN.md` contains `view ./...` or `view ../...`, resolve and read those files before guessing
4. If source code is in the workspace or a sibling directory, read route handlers
5. If still no reference but you know the minimum runnable facts, run an existing test or a small smoke test with `includeTraces: true` and read `responseSchema`
6. Only ask the user for more information when the minimum runnable facts are missing; ask for the smallest missing piece
7. If context is thin (spec only, no business rules), suggest adding product logic or `view ../...` pointers to `GLUBEAN.md` — see the template above

Never guess endpoint paths, request bodies, or auth requirements when reference material is available.
