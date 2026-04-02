# Projection — Contract Coverage Report

## Why this pattern

**Problem:** contract-first projects accumulate contracts, product intents, and regression tests across three directories. Nobody knows which features have contracts, which contracts are stable enough to promote, or whether the implementation has drifted from the contract.
**Alternative:** manually read every file and compare — but this doesn't scale past 10 contracts and the assessment is lost when the conversation ends.
**This pattern:** the agent reads all three layers, aligns them, and generates a persisted markdown report. PMs see feature-level progress and open decisions. Engineers see file-level status and action items.

## When to trigger

- The user asks: "what's my coverage", "which features are done", "show me contract status", "generate projection"
- **Proactively:** when `contracts/` has 5+ files, suggest a projection report

## Prerequisites

- `contracts/` exists with `.test.ts` files
- Optional: `product/` (enables product → contract alignment)
- Optional: `tests/` (enables contract → tests promotion tracking)

If `contracts/` does not exist, this pattern does not apply.

## Analysis steps

### Step 1: Collect inventory

1. Use `glubean_get_metadata` for project-wide inventory (files, test IDs, tags, counts)
2. If MCP is unavailable, use Glob + Read
3. Scan scope:
   - `product/` — start from `product/_index.md`, expand along the index tree
   - `contracts/` — all `.test.ts` files
   - `tests/` — all `.test.ts` files

### Step 2: Read product intent

If `product/` exists:
1. Read `product/_index.md` as entry point
2. Follow the index tree to each module
3. Extract intent summary per feature: name, key behaviors, acceptance criteria

If `product/` does not exist, skip product → contract alignment and note it in the report.

### Step 3: Read contracts

For each contract file:
1. Read test metadata: id, name, tags
2. Check `traceTo` field — if present, record the explicit traceability link
3. Check `status` field — draft / unresolved / stable / promoted
4. If `status` is missing, treat as `draft` and flag in the report
5. Scan for `// UNRESOLVED` markers
6. Note assertion type: `ctx.validate` (schema) vs `ctx.expect` (value) vs `.step()` (workflow)

### Step 4: Read tests

For each test file:
1. Read test metadata: id, name, tags
2. Match to contracts — prefer test ID prefix/suffix match, then endpoint path match

### Step 5: Alignment analysis

#### Product → Contract

For each product intent:
- Has `traceTo` pointing to it → `traced` (fact)
- No `traceTo` but semantic match → `inferred` (guess)
- No matching contract → `missing`

#### Contract → Tests

For each contract, check `status`:
- `promoted` → find corresponding test in `tests/`
- `stable` → "Ready to promote"
- `unresolved` or has `// UNRESOLVED` → "Not ready"
- `draft` → "Not ready — draft"

### Step 6: Schema drift detection (optional)

Only run when MCP is available AND the user explicitly asks or the agent detects drift signals.

**Observed drift** — run contract with `glubean_run_local_file` + `includeTraces: true`, compare `responseSchema` to contract schema. Label: `Source: observed (trace)`. This is fact.

**Inferred drift** — read codebase (route handlers, DB schema, types) and infer response shape. Label: `Source: inferred (code)`. This is a guess.

**Rule: never disguise inferred as observed.**

## Report format

The report has two sections separated by a horizontal rule. Top half for PMs, bottom half for engineers.

### Top half: Feature progress

1. **Status line** — one sentence: "{n} contracts, {x} in regression, {y} ready to promote, {z} missing"
2. **Delta** — if a previous projection exists in `projections/`, show what changed
3. **Features table** — grouped by domain, each row is a feature (not a file) with status icon and blocker
4. **Decisions needed** — blockers that require a human (PM/tech lead) decision, written in business language
5. **Progress bar** — visual regression/stable/coverage percentages

### Bottom half: Technical details

1. **Product → Contract alignment table** — file paths, traced/inferred, gaps
2. **Contract status table** — file paths, status, regression test, action
3. **Schema drift table** — expected vs actual, source label
4. **Action items** — numbered, concrete, executable

### Status icons

| Icon | Meaning |
|---|---|
| ✅ | In regression (promoted) |
| 🟡 | Contract stable, not yet in regression |
| 📝 | Draft — needs review |
| ⚠️ | Unresolved — has open questions |
| 🔴 | Missing — no contract exists |

## Output location

Write to `projections/{date}.md` (e.g. `projections/2026-04-02.md`).

These are committed artifacts — they track progress over time.

When generating, check `projections/` for the most recent previous report to compute the delta section.

## Traceability

### `traceTo` — contract to product anchor

```typescript
export const createUser = test({
  id: "create-user",
  tags: ["spec", "users"],
  traceTo: "product/modules/users/create.md",
}, async (ctx) => { ... });
```

### `## Related contracts` — product to contract reverse link

```markdown
## Related contracts

- `contracts/users/create-user.contract.test.ts`
```

### Agent behavior

- Prefer `traceTo` for alignment; fall back to semantic match only when missing
- Semantic fallback must be labeled `(inferred)` in the report
- If contracts lack `traceTo`, recommend adding it in action items

## Promotion status

| Status | Meaning | Agent behavior |
|---|---|---|
| `draft` | Just written, not reviewed | Do not suggest promote |
| `unresolved` | Has `// UNRESOLVED` or open questions | Do not suggest promote, list in report |
| `stable` | Reviewed and confirmed | Suggest promote |
| `promoted` | Has corresponding test in `tests/` | Mark as covered |

If `status` is missing, treat as `draft` and flag.
