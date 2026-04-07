# Discovery to Tests Promotion

## Why this pattern

**Problem:** `explore/` is great for discovery, but files stay there forever. They keep passing locally, yet they never become stable regression coverage in `tests/` or CI.

**This pattern:** promote stable exploratory files into `tests/` deliberately: tighten assertions, externalize shared types, replace interactive auth, and make the file CI-ready.

**Note:** `contract.http()` files in `contracts/` do NOT need promotion. They produce `Test[]` directly — `glubean run contracts` executes them as-is. Promotion applies mainly to `explore/` → `tests/`.

## When to promote

Promote a file from `explore/` to `tests/` when one or more of these are true:

- The same test has passed cleanly 3+ times without ad-hoc edits
- The user says "keep this", "make it regression coverage", or "put this in CI"
- The endpoint behavior is understood well enough to assert business values, not just reachability
- The flow is no longer an experiment and should protect against regressions

Keep the file in `explore/` when:

- The auth flow is still interactive or unstable
- The endpoint shape is still being discovered
- Assertions are intentionally shallow while learning the API

## What changes during promotion

| Area | `explore/` default | `tests/` target |
|---|---|---|
| Assertion depth | Level 1-2 | Level 2-3 stable regression |
| Types | Inline types are acceptable | Shared types go in `types/` |
| Schemas | Inline Zod is acceptable | Shared schemas go in `schemas/` |
| Auth | Interactive is acceptable for local exploration | Must be non-interactive and CI-safe |
| Data | Hardcoded payloads are acceptable for quick iteration | Shared fixtures should move to `data/` when reused |
| Tags | Often `explore` or ad-hoc | Stable regression tags (`api`, domain tags, smoke/crud/etc.) |

## Mechanical promotion steps

1. Move the file from `explore/` to `tests/`.
2. Update relative imports if files move or if extracted schemas/types are now shared.
3. Replace shallow assertions with schema or value assertions. See [assertions.md](assertions.md).
4. Move reusable response types into `types/*.ts`.
5. Move reusable Zod schemas into `schemas/*.ts`.
6. Replace interactive-only auth such as `oauthCode()` with a CI-safe strategy. See [auth.md](auth.md).
7. If the file represents a stable CRUD lifecycle, consider converting to `contract.http()` with cases or `contract.flow()` instead of promoting to `tests/`.
8. Remove `explore`-only tags and add stable regression tags.
9. Run the promoted file until it is green without manual intervention.
10. If the user wants automation, wire CI after the promoted tests are stable. See [../ci-workflow.md](../ci-workflow.md).

## Promotion checklist

Use this checklist before calling the file "ready for `tests/`":

- Auth does not require a browser or a manual login step during CI
- Assertions check business-critical values, not just status or `toBeDefined()`
- Volatile fields are not over-asserted
- Types and schemas are shared where reuse exists
- Test IDs and tags match project conventions
- Cleanup is reliable if the file creates data

## Common promotion traps

### 1. Copying shallow assertions into regression tests

```typescript
// Fine in explore/, too weak for tests/
ctx.expect(res.status).toBe(200);
ctx.expect(body.id).toBeDefined();
```

Prefer:

```typescript
ctx.expect(res.status).toBe(200);
ctx.expect(body.role).toBe("admin");
validate(body, UserSchema);
```

### 2. Keeping interactive auth in `tests/`

If the exploratory test uses `oauthCode()`, do not promote it as-is. Replace it with `oauth2.clientCredentials()`, `oauth2.refreshToken()`, or a pre-provisioned bearer token before moving it into `tests/`.

### 3. Leaving inline types in long-lived regression files

If the same response shape appears in more than one file, extract it into `types/` before or during promotion.

## Consider contract.http() instead

If the explore/ file is testing a well-defined API endpoint with clear cases, consider converting to `contract.http()` in `contracts/` instead of promoting to `tests/`. Contracts provide:

- Structured case model with required descriptions
- Automatic schema validation
- Scanner-extractable metadata for projection/coverage
- Setup/teardown per case

```typescript
// Instead of promoting this explore/ test to tests/:
export const getUser = test("get-user", async (ctx) => {
  const res = await api.get("users/1");
  ctx.expect(res.status).toBe(200);
  const body = await res.json();
  ctx.validate(body, UserSchema);
});

// Consider writing this in contracts/:
export const getUser = contract.http("get-user", {
  endpoint: "GET /users/:id",
  description: "Get user by ID.",
  client: api,
  cases: {
    success: {
      description: "Returns user with full profile.",
      params: { id: "1" },
      expect: { status: 200, schema: UserSchema },
    },
    notFound: {
      description: "Non-existent user returns 404.",
      params: { id: "nonexistent" },
      expect: { status: 404 },
    },
  },
});
```

## Suggested handoff message

When a file is ready, tell the user something like:

> This looks stable enough to move into `tests/`. I'll tighten the assertions, move shared types out of the file where needed, and make sure the auth setup is CI-safe. Alternatively, if this is a well-defined API endpoint, I can convert it to `contract.http()` in `contracts/` for richer spec coverage.
