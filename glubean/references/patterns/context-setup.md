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

The agent reads `_index.md` first, then only the endpoints it needs.

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

Structure each file for agent consumption — not human prose:

```markdown
# Users API

Base URL: `{{BASE_URL}}`

## POST /users
Create a user.

**Request:**
- Header: `Authorization: Bearer {{API_TOKEN}}`
- Body: `{ "email": string, "name": string, "role": "admin" | "member" }`

**Response 201:**
- `{ "id": string, "email": string, "name": string, "role": string, "createdAt": string }`

**Errors:**
- 400: missing required field
- 409: email already exists
- 403: caller is not admin

## GET /users/:id
...
```

Key: include request body shape, response body shape, and error codes. Skip prose descriptions the agent doesn't need.

### 4. No context (fallback)

If you have no spec, no docs, and no source code access, the agent can still work — but slower:

1. Write a smoke test with `includeTraces: true`
2. Read `responseSchema` from the trace to learn the response shape
3. Write real assertions based on what the API actually returns

This is the discovery-by-running approach. It works, but costs one MCP round-trip per endpoint.

## Decision table

| Situation | Recommended approach |
|---|---|
| You have an OpenAPI spec | Drop in `context/`, run `spec split` for large specs |
| Spec is incomplete or wrong | Add `.patch.yaml`, run `patch` |
| Testing your own API (source available) | Point at source code in `GLUBEAN.md` |
| Third-party API, no spec | Write markdown docs in `context/` |
| Nothing available | Discovery by running with traces |

## Agent behavior

When writing tests for an endpoint:

1. Check `context/` first — read `_index.md` or the relevant endpoint file
2. If no context exists, check `GLUBEAN.md` for API reference pointers
3. If still no reference, run an existing test with `includeTraces: true` and read `responseSchema`
4. Only after exhausting these sources, ask the user for API documentation

Never guess endpoint paths, request bodies, or auth requirements when reference material is available.
