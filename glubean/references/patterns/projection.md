# Projection — Contract Coverage Report

## Why this pattern

**Problem:** contract-first projects accumulate contracts across multiple files. Nobody knows which endpoints have contracts, which cases are deferred, or which status codes are covered across the API surface.

**This pattern:** use `glubean_extract_contracts` (MCP, richest data) or `glubean_project_contracts` (MCP) or `glubean contracts --format json` (CLI) to get structured contract data, then generate a human-readable report. Engineers see API surface coverage at a glance. PMs see which cases are done, deferred, or missing.

## When to trigger

- The user asks: "what's my coverage", "show me contract status", "generate projection", "which endpoints are covered"
- **Proactively:** when `contracts/` has 5+ files, suggest a projection report

## Prerequisites

- `contracts/` exists with `.contract.ts` files using `contract.http.with()` or `contract.flow()`
- Optional: `tests/` (additional coverage layer for cases contract can't express)

If `contracts/` does not exist or has no `contract.http.with()` files, this pattern does not apply.

## Data source

**Priority 1: MCP `glubean_extract_contracts`** — richest data source. Dynamically imports contract modules and returns full metadata including Zod schemas converted to JSON Schema, `instanceName`, security declarations, deferred reasons, requires, and defaultRun. Works for both legacy `contract.http()` and current `.with()` syntax.

**Priority 2: MCP `glubean_project_contracts`** — runtime extraction grouped by feature. Returns contracts, cases, descriptions, deferred reasons, requires, defaultRun, and summary stats. Does not include schemas.

**Priority 3: CLI** — if MCP is unavailable, run `glubean contracts --format json` via Bash. Same data as Priority 2, different channel.

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
- Deferred/deprecated/requires cases marked with ⊘
- Critical cases marked with 🔴, info cases marked with ℹ️ (warning is default, not marked)
- No status codes, HTTP methods, or endpoint paths in case lines
- Summary line at top: total cases, active, deferred, deprecated, gated

This is deterministic output — no agent involvement.

## Agent-generated report

When the user asks for a full coverage report, generate a two-section document:

### Top half: API surface status (for PMs)

1. **Status line** — one sentence: "{n} endpoints, {x} cases, {y} deferred, {z} deprecated, {w} missing schemas"
2. **Feature index** — table of features with case counts, lifecycle status, and severity distribution
3. **Deferred summary** — group deferred cases by reason (often reveals a single missing credential blocks many cases)
4. **Deprecated summary** — list deprecated cases with reasons (helps track API evolution)

### Bottom half: Technical details (for engineers)

1. **Endpoint detail** — endpoint, case name, status code, schema presence, deferred reason
2. **Flow coverage** — flow name, step count, gaps
3. **Gap analysis** — specific issues:
   - Endpoints with only one case (likely missing boundary coverage)
   - Cases missing `expect.schema` (no shape validation)
   - Deferred cases sharing the same reason (potential single-fix unblock)
   - Critical cases that are deferred (high-severity blockers)
   - Flow steps without corresponding endpoint specs
4. **Action items** — numbered, concrete, executable

### Status icons

| Icon | Meaning |
|---|---|
| ✅ | Case executable with full validation |
| ⚠️ | Case missing schema or weak assertion |
| ⏸ | Deferred — has reason, not yet runnable |
| 🚫 | Deprecated — retained for history, no longer executed |
| 🔴 | Critical severity — failure triggers immediate alert |
| ℹ️ | Info severity — informational check, no alert on failure |

## Instance-aware projection

When contracts use `.with("name", ...)`, projection groups by `instanceName → feature`. This reflects the actual API topology — different instances often represent different auth scopes or service boundaries.

Example output structure:

```
## public (3 endpoints, 8 cases)
### health .............. ✅ 2/2
### catalog ............. ✅ 4/4 ⏸ 2

## user (5 endpoints, 14 cases)
### profile ............. ✅ 3/3
### orders .............. ✅ 4/5 ⏸ 1

## admin (2 endpoints, 6 cases)
### users ............... ✅ 2/4 ⏸ 2
### audit ............... ⏸ 0/2 (deferred: admin credentials)
```

OpenAPI generation via `glubean_openapi` produces per-instance specs, each with its own `securitySchemes` derived from instance security declarations.

## Agent behavior

- Use `glubean_extract_contracts` when you need schema information (richest data)
- Use `glubean_openapi` when the user asks for an API spec or OpenAPI document
- Both tools work for `.with()` scoped contracts
- Fall back to `glubean_project_contracts` or `glubean contracts --format json` when extract/openapi tools are unavailable
- Never parse contract files manually
- Never generate the report if `contracts/` has no `contract.http.with()` files — suggest writing contracts first
- When a case is `deferred` or `deprecated`, include the reason verbatim in the report
- When multiple deferred cases share a reason, group them to suggest single-fix unblocks
- When a case has `severity: "critical"` and is deferred, flag it as a high-priority blocker

## MCP tools reference

### `glubean_extract_contracts`

Runtime extraction tool that dynamically imports contract modules. Returns protocol-agnostic `NormalizedContractMeta` including:
- `protocol`, `target` (protocol-agnostic endpoint identifier)
- `lifecycle` (`"active"` | `"deferred"` | `"deprecated"`) and `severity` (`"critical"` | `"warning"` | `"info"`)
- Zod schemas converted to JSON Schema (request body, response body, query params)
- `instanceName` from `.with("name", ...)` declarations
- Security declarations from instance configuration
- All standard fields: cases, descriptions, deferred/deprecated reasons, requires, defaultRun
- `protocolExpect` for protocol-specific expectations (e.g. HTTP status code)

Works for `.with()` syntax and plugin protocol contracts (`contract.register()` with adapter v2).

### `glubean_openapi`

Generates an OpenAPI 3.1 spec from contract definitions. Only processes `protocol: "http"` contracts; non-HTTP protocols are skipped. Features:
- `securitySchemes` derived from instance security declarations
- HTTP status codes read from `protocolExpect.status`
- `oneOf` discriminator from `z.discriminatedUnion()` schemas
- Per-instance spec generation when contracts use `.with()`
- Can generate a spec without running tests — useful for documentation and client codegen

**OpenAPI field coverage (Phase 1 + Phase 2):**
- `expect.schema` → `responses[status].content[contentType].schema`
- `expect.example` / `expect.examples` → `responses[status].content[contentType].examples` (merged across all cases sharing a status/content-type; keyed by case name to avoid collision)
- `expect.headers` → `responses[status].headers` (merged across cases; first case wins on header name conflicts)
- `expect.contentType` → per-case content type dispatch in responses (the same status with different content types produces multiple `content[]` entries)
- Contract-level `deprecated` → operation `deprecated: true` + `x-deprecated-reason`
- `ParamValue` fields (`schema`, `description`, `required`, `deprecated`) → `parameters[].schema/.description/.required/.deprecated`; merged at FIELD level across cases so each case can contribute different metadata for the same param
- `request.headers` (JSON Schema with `properties` + `required`) → `parameters[in=header]` entries
- `request.example` / `request.examples` → `requestBody.content[contentType].examples`
- `request.contentType` → `requestBody.content[contentType]` (default `application/json`)
- `extensions` (merged `defaults < contract < case`) → `x-*` fields on the operation

### `glubean_project_contracts`

Lightweight runtime extraction grouped by feature. Returns contracts, cases, descriptions, lifecycle, severity, deferred/deprecated reasons, requires, defaultRun, and summary stats (including deprecated count and severity distribution). Does not include schemas or security metadata.

## Notes

- `contract.http.with()` produces `Test[]` directly — no promotion step. Contracts ARE the regression tests. The projection report is about spec coverage, not "stable vs draft" lifecycle.
- If the project has both `contracts/` and `tests/`, the report focuses on `contracts/`. `tests/` content is treated as supplementary coverage for browser/polling/complex state scenarios.
- Endpoint lists, case inventories, deferred coverage, and similar interface-layer views should be generated from `contracts/`, not maintained as separate prose docs.
