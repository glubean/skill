# Projection — Contract Coverage Report

## Why this pattern

**Problem:** contract-first projects accumulate contracts across multiple files. Nobody knows which endpoints have contracts, which cases are deferred, or which status codes are covered across the API surface.

**This pattern:** use `glubean_project_contracts` (MCP) or `glubean contracts --format json` (CLI) to get structured contract data, then generate a human-readable report. Engineers see API surface coverage at a glance. PMs see which cases are done, deferred, or missing.

## When to trigger

- The user asks: "what's my coverage", "show me contract status", "generate projection", "which endpoints are covered"
- **Proactively:** when `contracts/` has 5+ files, suggest a projection report

## Prerequisites

- `contracts/` exists with `.contract.ts` files using `contract.http()` or `contract.flow()`
- Optional: `tests/` (additional coverage layer for cases contract can't express)

If `contracts/` does not exist or has no `contract.http()` files, this pattern does not apply.

## Data source

**Priority 1: MCP tool** — call `glubean_project_contracts` to get structured JSON grouped by feature. This returns contracts, cases, descriptions, deferred reasons, requires, defaultRun, and summary stats.

**Priority 2: CLI** — if MCP is unavailable, run `glubean contracts --format json` via Bash. Same data, different channel.

**Do NOT manually Glob + Read contract files.** The scanner handles extraction; use the tools above.

## Quick output — md-outline

For a quick spec dump without agent processing, the user can run:

```bash
glubean contracts                    # human-readable markdown
glubean contracts --format json      # machine-readable
```

The `md-outline` format outputs:
- Feature as h2 heading
- Contract description as intro line
- Each case as a bullet: **key** — description
- Deferred/requires cases marked with ⊘
- No status codes, HTTP methods, or endpoint paths in case lines
- Summary line at top: total cases, active, deferred, gated

This is deterministic output — no agent involvement.

## Agent-generated report

When the user asks for a full coverage report, generate a two-section document:

### Top half: API surface status (for PMs)

1. **Status line** — one sentence: "{n} endpoints, {x} cases, {y} deferred, {z} missing schemas"
2. **Feature index** — table of features with case counts and status
3. **Deferred summary** — group deferred cases by reason (often reveals a single missing credential blocks many cases)

### Bottom half: Technical details (for engineers)

1. **Endpoint detail** — endpoint, case name, status code, schema presence, deferred reason
2. **Flow coverage** — flow name, step count, gaps
3. **Gap analysis** — specific issues:
   - Endpoints with only one case (likely missing boundary coverage)
   - Cases missing `expect.schema` (no shape validation)
   - Deferred cases sharing the same reason (potential single-fix unblock)
   - Flow steps without corresponding endpoint specs
4. **Action items** — numbered, concrete, executable

### Status icons

| Icon | Meaning |
|---|---|
| ✅ | Case executable with full validation |
| ⚠️ | Case missing schema or weak assertion |
| ⏸ | Deferred — has reason, not yet runnable |

## Agent behavior

- Always use `glubean_project_contracts` MCP tool or `glubean contracts --format json` — never parse contract files manually
- Never generate the report if `contracts/` has no `contract.http()` files — suggest writing contracts first
- When a case is `deferred`, include the reason verbatim in the report
- When multiple deferred cases share a reason, group them to suggest single-fix unblocks

## Notes

- `contract.http()` produces `Test[]` directly — no promotion step. Contracts ARE the regression tests. The projection report is about spec coverage, not "stable vs draft" lifecycle.
- If the project has both `contracts/` and `tests/`, the report focuses on `contracts/`. `tests/` content is treated as supplementary coverage for browser/polling/complex state scenarios.
- Endpoint lists, case inventories, deferred coverage, and similar interface-layer views should be generated from `contracts/`, not maintained as separate prose docs.
