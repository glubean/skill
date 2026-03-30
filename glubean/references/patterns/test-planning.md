# Test Planning — Systematic Coverage from API Knowledge

## Why this matters

**Problem:** users ask "write tests for my API" but don't specify which scenarios to cover. The agent defaults to one smoke test + one CRUD test per endpoint, missing auth boundaries, validation rules, edge cases, and error paths.
**Alternative:** wait for the user to list every scenario — but most users don't know what to ask for, so coverage stays shallow.
**This pattern:** the agent proactively analyzes the API surface, derives a test plan across multiple dimensions, and presents it for confirmation before writing. The user reviews and adjusts — they don't need to be a test planning expert.

## When to use this

- User asks to "write tests for [API / endpoint / service]" without specifying exact scenarios
- User asks for "good coverage" or "comprehensive tests"
- User asks to "improve test coverage" or "what am I missing?"
- Agent is about to write tests for 3+ endpoints
- Agent has access to OpenAPI spec, source code, or API docs in `context/`

For single-endpoint requests ("write a smoke test for /health"), skip the full planning process — just write the test.

## Step 1: Gather API knowledge

Before planning, read everything available. Priority order:

1. `context/*-endpoints/_index.md` or another curated `context/_index.md` (split or curated API index)
2. `context/openapi.json` or `.yaml` (full spec)
3. `GLUBEAN.md` — project-specific conventions, business rules, product context
4. Any files pointed to by `view ./...` or `view ../...` in `GLUBEAN.md`
5. Source code route handlers (if accessible, see `GLUBEAN.md`)
6. Existing tests in `tests/` and `explore/` (learn what's already covered)
7. Run a few endpoints with `includeTraces: true` to discover response shapes

If context is thin or missing, do not stop only to ask the user to set it up. Suggest that they add pointers in `GLUBEAN.md` or reference files in `context/`, then continue with whatever evidence is already available. Only ask for more information when the minimum runnable facts are missing, such as no known endpoint, no base URL, or no auth evidence.

If there is a single large OpenAPI file but no split endpoint docs, suggest `glubean spec split context/openapi.json` or `npx glubean@latest spec split context/openapi.json`. The agent can still continue with the full spec, but split files make endpoint-by-endpoint planning much more reliable and save context tokens for other useful inputs such as business rules, source pointers, and existing tests.

### Context quality check

The quality of test coverage depends directly on what context the agent has. Before starting the analysis, assess what's available and what's missing:

| Context source | What it gives you | Without it |
|---|---|---|
| **API spec / source code** | Endpoint paths, request/response shapes, status codes | Agent guesses paths and field names — many run failures |
| **Product / business logic** | Validation rules, role permissions, state machines, edge cases | Agent only tests the obvious happy path — misses the bugs that matter |
| **Existing tests** | What's already covered, project conventions | Agent may duplicate coverage or use inconsistent patterns |

If the agent only has an API spec but no product context, proactively suggest:

> I can see the API endpoints, but I don't have product context — things like business rules, role permissions, or validation logic. Adding this to `GLUBEAN.md` or `context/` would help me write more targeted tests. For example:
>
> **In `GLUBEAN.md`:**
> ```markdown
> ## Business Rules
> - Only admins can delete users. Non-admin DELETE returns 403.
> - Email must be unique. Duplicate POST returns 409.
> - Projects in "archived" state cannot be updated. PUT returns 422.
> - Free-tier users are limited to 5 projects. 6th create returns 402.
>
> ## Product References
> - view ../product/requirements.md
> - view ../api/src/routes/users.ts
> ```
>
> Even a few sentences about how the system works, or a few `view ../...` pointers to the right files, will significantly improve test coverage.

If source code is in the workspace or a sibling directory, mention that too:

> I see the API source code is in `../api/src/routes/`. I can read the route handlers to understand validation rules and error paths. You can also add `view ../api/src/routes/` to `GLUBEAN.md` so future test work picks it up faster.

Never skip this check. The difference between "API spec only" and "spec + product context" is the difference between surface-level tests and tests that catch real bugs. This is a reminder, not a gate: continue with available evidence unless the minimum runnable facts are missing.

## Step 2: Analyze each endpoint

For every endpoint, systematically extract:

| Dimension | What to look for | Where to find it |
|---|---|---|
| **Auth** | Which auth scheme? Public or protected? Role-based? | `securitySchemes`, middleware, `GLUBEAN.md` |
| **Required inputs** | Which fields are required? What types? | `required` in schema, validation middleware, request body schema |
| **Optional inputs** | Query params, pagination, sorting, filtering? | `parameters` in spec, handler code |
| **Success response** | Status code, response body shape, key fields | `responses.200`, handler return |
| **Error responses** | Which 4xx/5xx codes? Error body format? | `responses.4xx`, validation rules, try/catch in handler |
| **Side effects** | Creates/updates/deletes resources? Sends emails? Triggers jobs? | Handler logic, DB operations |
| **Constraints** | Uniqueness, max length, enum values, rate limits? | DB schema, validation rules, spec `enum`/`maxLength` |
| **Relations** | Depends on other resources existing? Cascade on delete? | Foreign keys, handler checks |

Don't try to answer every dimension for every endpoint — extract what the source material gives you.

## Coverage audit for existing suites

When the user asks to improve coverage, find gaps, or asks "what am I missing?", do not start from a blank test plan. Start by inventorying the existing suite.

### Preferred audit order

1. Use `glubean_get_metadata` if MCP is available. It gives you project-wide file count, test count, tags, and file inventory without opening every file.
2. Use `glubean_list_test_files` to discover test files if metadata is unavailable or incomplete.
3. Use `glubean_discover_tests` on the most relevant files to extract IDs, names, and tags without running them.
4. Read only the files needed to confirm coverage depth or understand conventions.
5. Cross-reference the current suite against `context/`, split endpoint docs, or the OpenAPI spec.

### Gap categories

For each endpoint or domain, classify coverage into one of these buckets:

| Gap type | What it means | Typical follow-up |
|---|---|---|
| **Untested endpoint** | Exists in spec/source, no corresponding test file or test ID | Add smoke first, then deeper tests if important |
| **Smoke only** | Only reachability/status checks exist | Add schema/value assertions, validation, and auth boundaries |
| **Happy path only** | Write path works, but no negatives | Add 4xx validation, duplicate, and permission tests |
| **Auth gap** | Protected endpoint lacks 401/403 coverage | Add auth boundary tests after confirming strategy |
| **Query gap** | List/search endpoint lacks pagination/filter/sort coverage | Add `test.each` variations |
| **State / relation gap** | Resource workflow or dependencies are untested | Add builder lifecycle or dependency setup tests |

### Gap report shape

Present the result as a gap report before writing code:

```
## Coverage Gap Report: Users API

### Inventory
- 6 test files, 18 tests total
- Existing tags: smoke, users, auth

### Covered well
- GET /users/:id — read path and schema checks

### Gaps
- POST /users — only smoke coverage, no validation or duplicate-email test
- DELETE /users/:id — no non-admin 403 coverage
- GET /users — no pagination or sort coverage
- PATCH /users/:id — endpoint exists in spec, no test file found

### Proposed additions
- 1 smoke file for uncovered endpoints
- 1 validation/auth file for POST/DELETE
- 1 data-driven list file for pagination and sorting
```

Use `glubean_get_metadata` as the fast inventory step, not as the final answer. It tells you what files and tags exist; the spec and selected test files tell you what is still missing.

## Step 3: Derive test scenarios

Map each endpoint's analysis to concrete test scenarios using these coverage dimensions:

### Coverage dimensions (ordered by priority)

**1. Reachability (always)**
- Can the endpoint be reached? Does auth work? Does the basic happy path return the expected status?
- → smoke test

**2. CRUD round-trip (for write endpoints)**
- Create → Read → verify match → Update → verify change → Delete → verify gone
- → builder lifecycle test

**3. Input validation (for endpoints with request body)**
- Missing required fields → expected error
- Wrong types → expected error
- Boundary values (empty string, zero, max length, negative numbers)
- → error / negative tests

**4. Auth boundaries (for protected endpoints)**
- No auth → 401
- Wrong role / insufficient scope → 403
- Expired token → 401
- → error tests with auth variations

**5. Query variations (for list/search endpoints)**
- Pagination: first page, last page, page beyond range
- Filtering: valid filter, invalid filter, no results
- Sorting: each sort field, ascending/descending
- → data-driven tests with `test.each`

**6. Edge cases (from constraints)**
- Duplicate create → 409
- Delete non-existent → 404
- Update with no changes → still 200?
- Concurrent modifications (if relevant)
- → targeted tests per case

**7. Relationships (for connected resources)**
- Create child without parent → expected error
- Delete parent with children → cascade or reject?
- → builder tests with setup dependencies

### What to skip

- Performance testing (unless the user specifically asks)
- Rate limiting (hard to test deterministically)
- Internal implementation details (DB queries, cache behavior)
- UI-specific behavior (unless testing browser endpoints)

## Step 4: Present the plan

Before writing any test code, present a structured plan to the user:

```
## Test Plan: Users API

### Endpoints analyzed
- POST /users (create)
- GET /users (list with pagination)
- GET /users/:id (get by ID)
- PUT /users/:id (update)
- DELETE /users/:id (delete)

### Proposed tests

**Smoke (1 file, 5 tests)**
- Each endpoint returns expected status with valid input

**CRUD lifecycle (1 file, 1 builder test)**
- Create → Read → Update → Delete with teardown

**Input validation (1 file, 4 tests)**
- POST /users with missing email → 422
- POST /users with invalid email format → 422
- PUT /users/:id with empty name → 422
- POST /users with duplicate email → 409

**Auth boundaries (1 file, 3 tests)**
- GET /users without token → 401
- DELETE /users/:id as non-admin → 403
- POST /users with expired token → 401

**Pagination (1 file, data-driven)**
- GET /users?page=1&limit=10 — first page
- GET /users?page=999 — beyond range → empty or 404
- GET /users?sort=name&order=desc — sort order

**Total: ~15 tests across 5 files**

Want me to proceed, or adjust the plan?
```

### Plan format rules

- Group by coverage dimension, not by endpoint
- Show file count and test count — the user should know the scope
- Flag any gaps: "I couldn't determine auth requirements — do these endpoints require a token?"
- Always ask for confirmation before writing

## Step 5: Write in priority order

After confirmation, write tests in this order:

1. **Smoke first** — verifies the API is reachable and auth works
2. **CRUD lifecycle** — verifies the write path end-to-end
3. **Error / validation** — verifies rejection of bad input
4. **Auth boundaries** — verifies access control
5. **Data-driven / edge cases** — verifies variations and corner cases

Run each file after writing it. Don't write all 5 files then run them all — failures in early files (auth misconfigured, wrong base URL) will cascade.

## Scaling down

Not every API needs the full analysis. Scale to context:

| Situation | Approach |
|---|---|
| User says "smoke test for /health" | Just write it — no plan needed |
| User says "test the /users endpoint" | Quick analysis of that one endpoint, propose 3-5 tests |
| User says "write tests for my API" | Full Step 1-5 analysis across all endpoints |
| User says "improve test coverage" | Run the coverage audit first, then propose additions in priority order |

## Working with incomplete knowledge

When the source material doesn't answer a dimension:

- **Don't guess** — flag it in the plan as an open question
- **Don't skip** — still propose the test, note the assumption
- **Prefer discovery** — run the endpoint with traces to find out

Example: "I can't tell from the spec whether DELETE /users/:id requires admin role. I'll include an auth boundary test assuming it does — let me know if that's wrong."
