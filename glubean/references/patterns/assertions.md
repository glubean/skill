# Assertion Complexity — Choosing the Right Depth

## Why this matters

**Problem:** agents default to either too shallow (`toBeDefined()` on everything) or too deep (assert timestamps, UUIDs, array order) — shallow misses real bugs, deep causes flaky tests.
**Alternative:** copy assertion style from nearby test files — but if the project is new or the existing tests are bad, this propagates the wrong depth.
**This pattern:** match assertion depth to the test's purpose and directory. The rules below tell you exactly which assertions to write and which to skip.

## Assertion levels

| Level | What it checks | Example | When to use |
|---|---|---|---|
| **1. Reachability** | API is up, auth works, status is correct | `expect(res).toHaveStatus(200)` | Smoke tests, first test for a new endpoint |
| **2. Shape** | Response structure matches expected schema | `validate(res, UserSchema)` | Contract tests, regression on response structure |
| **3. Value** | Specific business values are correct | `expect(user.role).toBe("admin")` | Business logic verification, CRUD round-trips |
| **4. Exhaustive** | Every field, exact match | `expect(res).toEqual({ ... })` | Almost never — too brittle |

## Decision rules

### By directory

| Directory | Default level | Rationale |
|---|---|---|
| `explore/` | Level 1–2 | You are discovering the API. Assert status and rough shape, not exact values. You will tighten assertions when promoting to `tests/`. |
| `tests/` | Level 2–3 | This is regression coverage. Assert the structure (schema) and business-critical values, but not volatile fields. |

### By test purpose

| Purpose | Level | Example assertions |
|---|---|---|
| Smoke / health check | 1 | `toHaveStatus(200)`, `toBeDefined()` |
| Endpoint exploration | 1–2 | `toHaveStatus(200)`, check key fields exist |
| CRUD round-trip | 3 | Assert created values match input, update changes the right field, delete returns 404 on re-read |
| Schema / contract | 2 | `validate(body, Schema)` — one Zod schema covers all fields |
| Error / negative | 3 | `toHaveStatus(422)`, `expect(body.message).toContain("name")` |
| Performance | 1 + metric | `toHaveStatus(200)` + `metric("latency", duration)` |

### What to assert vs what to skip

| Assert | Skip |
|---|---|
| Status code | Exact timestamps (`createdAt`, `updatedAt`) |
| Business fields (`name`, `email`, `status`, `role`) | Auto-generated IDs (unless verifying round-trip) |
| Array length or `length > 0` | Exact array ordering (unless the API guarantees it) |
| Error message keywords | Full error message strings (they change) |
| Response schema shape (Zod) | Headers you don't control (`X-Request-Id`, `Date`) |
| Values you just wrote (CRUD round-trip) | Default values the API may change between versions |

## Common mistakes

### Over-assertion (causes flaky tests)

```typescript
// ❌ Asserts timestamp — fails on every run
expect(user.createdAt).toBe("2025-01-15T10:00:00Z");

// ✅ Assert it exists and is a valid date
expect(user.createdAt).toBeDefined();

// ❌ Asserts exact array order — fails if API changes sort
expect(users[0].name).toBe("Alice");

// ✅ Assert the array contains the expected item
expect(users.some(u => u.name === "Alice")).toBe(true);

// ❌ Asserts auto-generated ID
expect(user.id).toBe("usr_abc123");

// ✅ Assert it has the right format
expect(user.id).toMatch(/^usr_/);
```

### Under-assertion (misses real bugs)

```typescript
// ❌ Only checks status — misses wrong response body
expect(res).toHaveStatus(200);

// ✅ Check status AND the key business field
expect(res).toHaveStatus(200);
const body = await res.json<{ name: string }>();
expect(body.name).toBe("test-project");

// ❌ Only checks toBeDefined — misses wrong type
expect(user.email).toBeDefined();

// ✅ Use schema validation to catch type mismatches
validate(user, UserSchema);
```

### Right level for CRUD round-trips

```typescript
// In a CRUD test, assert that write → read returns what you wrote:
.setup(async () => {
  const created = await api.post("projects", {
    json: { name: "test-project" },
  }).json<{ id: string; name: string }>();
  return { id: created.id, name: created.name };
})
.step("read", async ({ expect }, state) => {
  const project = await api.get(`projects/${state.id}`).json<{ name: string }>();
  // ✅ Assert the value you just wrote — this is level 3, appropriate here
  expect(project.name).toBe(state.name);
})
```

## Promoting from explore to tests

When moving a test from `explore/` to `tests/`:

1. Replace `toBeDefined()` with schema validation for the response body
2. Add value assertions for business-critical fields
3. Keep skipping volatile fields (timestamps, auto-IDs)
4. Add error boundary tests alongside the happy path
