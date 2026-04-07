# Projection — Contract Coverage Report

## Why this pattern

**Problem:** contract-first projects accumulate contracts across multiple files. Nobody knows which endpoints have contracts, which cases are deferred, or which status codes are covered across the API surface.

**This pattern:** the agent reads all `contract.http()` declarations, extracts case-level metadata (endpoint, status codes, deferred reasons, descriptions), and generates a persisted markdown report. Engineers see API surface coverage at a glance. PMs see which cases are done, deferred, or missing.

## When to trigger

- The user asks: "what's my coverage", "show me contract status", "generate projection", "which endpoints are covered"
- **Proactively:** when `contracts/` has 5+ files, suggest a projection report

## Prerequisites

- `contracts/` exists with `.contract.ts` files using `contract.http()` or `contract.flow()`
- Optional: `tests/` (additional coverage layer for cases contract can't express)

If `contracts/` does not exist or has no `contract.http()` files, this pattern does not apply.

## Analysis steps

### Step 1: Collect contract inventory

1. Use `glubean_get_metadata` for project-wide inventory
2. If MCP is unavailable, use Glob + Read on `contracts/**/*.contract.ts`
3. For each file, extract:
   - Contract ID (from `contract.http("id", ...)`)
   - Endpoint (method + path)
   - Top-level `description`
   - Each case: key, `description`, `expect.status`, `deferred` reason if present
   - Tags at contract and case level

### Step 2: Build API surface map

Group by endpoint. For each endpoint, list:
- All declared cases with status codes
- Deferred cases with reason
- Whether schema validation is present (`expect.schema` defined)

Example:
```
POST /users
  ├─ success (201) ✅ with schema
  ├─ invalidBody (400) ✅
  ├─ duplicate (409) ✅ with schema
  └─ viewerBlocked (403) ⏸ deferred: needs VIEWER_API_KEY

GET /users/:id
  ├─ success (200) ✅ with schema
  └─ notFound (404) ✅
```

### Step 3: Flow coverage

For each `contract.flow()`:
1. Read the step chain (name, endpoint, expected status)
2. Verify each flow step's endpoint has a corresponding `contract.http()` spec
3. Flag flows whose steps don't have matching endpoint contracts

### Step 4: Gap analysis

Look for common gaps:
- Endpoints with only one case (likely missing boundary coverage)
- Cases missing `expect.schema` (no shape validation)
- Deferred cases sharing the same reason (potential single-fix unblock)
- Flow steps without corresponding endpoint specs
- Flows that don't verify the uploaded artifact (weak lifecycle assertions)

## Report format

The report has two sections separated by a horizontal rule. Top half for PMs, bottom half for engineers.

### Top half: API surface status

1. **Status line** — one sentence: "{n} endpoints, {x} cases, {y} deferred, {z} missing schemas"
2. **Delta** — if a previous projection exists in `projections/`, show what changed
3. **Endpoint table** — grouped by resource, each row an endpoint with case count and coverage status
4. **Deferred summary** — group deferred cases by reason (often reveals a single missing credential blocks many cases)
5. **Progress bar** — visual case coverage percentage

### Bottom half: Technical details

1. **Endpoint detail table** — endpoint, case name, status code, schema presence, deferred reason
2. **Flow coverage table** — flow name, step count, gaps
3. **Gap analysis** — specific cases flagged by Step 4
4. **Action items** — numbered, concrete, executable

### Status icons

| Icon | Meaning |
|---|---|
| ✅ | Case executable with full validation |
| ⚠️ | Case missing schema or weak assertion |
| ⏸ | Deferred — has reason, not yet runnable |
| 🔴 | Missing — endpoint has no contract at all |

## Output location

Write to `projections/{date}.md` (e.g. `projections/2026-04-07.md`).

These are committed artifacts — they track progress over time.

When generating, check `projections/` for the most recent previous report to compute the delta section.

## What to extract from contracts

### Required fields (from `contract.http()`)

- `id` — contract identifier
- `endpoint` — HTTP method + path
- `description` — contract-level intent
- Each case in `cases`:
  - `description` — case intent (required)
  - `expect.status` — expected status code
  - `expect.schema` — whether schema validation is present
  - `deferred` — reason if case is not executable

### Optional fields

- `tags` — for filtering/grouping
- `request` — endpoint-level request schema (if defined)

### Flow contracts (from `contract.flow()`)

- Flow ID
- Each `.http()` step: name, endpoint, expected status
- Setup/teardown presence

## Agent behavior

- Prefer scanner output (`glubean_get_metadata`) when MCP is available — it reads the registry directly
- Fall back to Glob + Read parsing if MCP unavailable
- Never generate the report if `contracts/` has no `contract.http()` files — suggest writing contracts first
- When a case is `deferred`, include the reason verbatim in the report
- When multiple deferred cases share a reason, group them to suggest single-fix unblocks

## Notes

- `contract.http()` produces `Test[]` directly — no promotion step. Contracts ARE the regression tests. The projection report is about spec coverage, not "stable vs draft" lifecycle.
- If the project has both `contracts/` and `tests/`, the report focuses on `contracts/`. `tests/` content is treated as supplementary coverage for browser/polling/complex state scenarios.
