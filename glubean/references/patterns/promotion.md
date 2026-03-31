# Discovery or Contract to Tests Promotion

## Why this pattern

**Problem:** `explore/` is great for discovery, and `contracts/` is great for executable contract definition, but many users get stuck there. Files keep passing locally, yet they never become stable regression coverage in `tests/` or CI.
**Alternative:** just move the file into `tests/` unchanged — but that usually preserves shallow assertions, draft-only semantics, inline types, or interactive-only auth.
**This pattern:** promote stable exploratory or contract-first files into `tests/` deliberately: tighten assertions, externalize shared types, replace interactive auth, and make the file CI-ready.

## When to promote

Promote a file from `explore/` or `contracts/` to `tests/` when one or more of these are true:

- The same test has passed cleanly 3+ times without ad-hoc edits
- The user says "keep this", "make it regression coverage", or "put this in CI"
- The endpoint behavior is understood well enough to assert business values, not just reachability
- The flow is no longer an experiment and should protect against regressions

Additional signal for `contracts/`:

- The contract is no longer draft-only and now represents stable implemented behavior worth protecting in CI

Keep the file in `explore/` when:

- The auth flow is still interactive or unstable
- The endpoint shape is still being discovered
- Assertions are intentionally shallow while learning the API

Keep the file in `contracts/` when:

- It is still the primary executable contract source of truth
- It still contains unresolved notes or expected-red semantics
- It defines behavior broader than the specific stable regression slice you want in `tests/`

## What changes during promotion

| Area | `explore/` default | `contracts/` default | `tests/` target |
|---|---|---|---|
| Assertion depth | Level 1-2 | Contract-level shape + key values | Level 2-3 stable regression |
| Types | Inline types are acceptable | Shared types preferred as contracts stabilize | Shared types go in `types/` |
| Schemas | Inline Zod is acceptable | Shared schemas preferred as contracts stabilize | Shared schemas go in `schemas/` |
| Auth | Interactive is acceptable for local exploration | Placeholder or draft semantics may exist early | Must be non-interactive and CI-safe |
| Structure | Separate exports are fine for interactive runs | Contract-oriented grouping by endpoint/resource/workflow | Prefer regression-oriented grouping and reusable setup |
| Data | Hardcoded payloads are acceptable for quick iteration | Intentional examples may exist in contracts | Shared fixtures should move to `data/` when reused |
| Tags | Often `explore` or ad-hoc | Often `spec`, `contract`, domain tags | Stable regression tags (`api`, domain tags, smoke/crud/etc.) |

## Mechanical promotion steps

1. Decide whether to move or copy.
2. For `explore/`, moving into `tests/` is often fine once the behavior is stable.
3. For `contracts/`, prefer keeping the contract file as source of truth and creating a stable regression-oriented counterpart in `tests/` when only part of the contract surface belongs in CI.
4. Update relative imports if files move or if extracted schemas/types are now shared.
5. Replace shallow assertions with schema or value assertions. See [assertions.md](assertions.md).
6. Move reusable response types into `types/*.ts`.
7. Move reusable Zod schemas into `schemas/*.ts`.
8. Replace interactive-only auth such as `oauthCode()` with a CI-safe strategy. See [auth.md](auth.md).
9. If the file represents a stable CRUD lifecycle, consider converting separate exploratory exports into a builder regression flow. See [crud.md](crud.md).
10. Remove `explore`-only or draft-only tags and add stable regression tags.
11. Run the promoted file until it is green without manual intervention.
12. If the user wants automation, wire CI after the promoted tests are stable. See [../ci-workflow.md](../ci-workflow.md).

## Promotion checklist

Use this checklist before calling the file "ready for `tests/`":

- Auth does not require a browser or a manual login step during CI
- Assertions check business-critical values, not just status or `toBeDefined()`
- Volatile fields are not over-asserted
- Types and schemas are shared where reuse exists
- Test IDs and tags match project conventions
- Cleanup is reliable if the file creates data
- For `contracts/`, draft-only notes or unresolved semantics are not copied into the regression file

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

### 4. Treating `contracts/` as disposable after promotion

Do not move all contract-first truth into `tests/` and abandon `contracts/`. `contracts/` remains the broader executable contract layer; `tests/` is the stable regression subset.

## Suggested handoff message

When a file is ready, tell the user something like:

> This looks stable enough to promote into `tests/`. I'll tighten the assertions, move shared types out of the file where needed, and make sure the auth setup is CI-safe before wiring it into automation.
