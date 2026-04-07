# Project Mode

Glubean has two modes. **Simple mode is the default.** Contract-first is an advanced structured path.

## Shared setup

1. Run [diagnose.md](diagnose.md) only when: first time seeing this project, something fails unexpectedly, or the user explicitly asks. The route-first checks in SKILL.md are enough for normal visits.
2. If `@glubean/sdk` is missing from dependencies, stop and have the user run `npx glubean@latest init`. Other missing pieces (directories, env files) are not blocking — note them and continue.
3. Read `GLUBEAN.md` when it exists. Read any user-specified context locations before guessing.

Then pick a mode based on intent and project structure.

## Simple mode (default — test-after)

**When to use:**
- API already exists and is callable
- User asks "write tests", "improve coverage", "fix this test", "test endpoint X"
- Project has `explore/` and/or `tests/` directories, no `contracts/`

**Workflow:**
- `explore/` — fast local iteration, interactive discovery
- `tests/` — stable regression, runs in CI
- Promote stable files from `explore/` to `tests/` when they're CI-ready

**Steps:**
1. Read [test-after-workflow.md](test-after-workflow.md) for the step-by-step writing workflow.
2. If the ask is broad coverage work, read [patterns/test-planning.md](patterns/test-planning.md) before writing code.
3. If the user is migrating from Postman, Apifox, OpenAPI, `.http`, cURL, or another test codebase, read [patterns/migration.md](patterns/migration.md) before generating files.
4. Use extension + MCP for local run/fix loops.
5. Move stable coverage into `tests/`, then suggest CI. See [patterns/promotion.md](patterns/promotion.md).

## Contract-first mode (advanced — structured spec)

**When to use:**
- API doesn't exist yet — define behavior first, implement to satisfy
- User wants structured spec with scanner-extractable metadata, coverage matrix, or Cloud projection
- Project has `contracts/` with `contract.http()` / `contract.flow()` files
- User explicitly says "contract", "spec", "define API"

**Workflow:**
- `contracts/` — `contract.http()` and `contract.flow()` as direct executable specs
- `schemas/` — reusable Zod response schemas
- `tests/` — only for cases contract can't express (browser, polling, complex state machines)
- **No `explore/ → contracts/` transition, no `contracts/ → tests/` promotion.** `contract.http()` produces `Test[]` directly.

**Steps:**
1. Read [contract-first.md](contract-first.md) for the entry workflow, then [patterns/contract-first.md](patterns/contract-first.md) for the full writing guide.
2. Write contracts in `contracts/` using `contract.http()` with `cases`. Each case has a required `description`.
3. Keep Zod schemas in `schemas/`. Use `expect.schema` for response validation.
4. Use `contract.flow()` for cross-endpoint lifecycle verification.
5. If the user asks about coverage status, or `contracts/` has 5+ files, suggest a projection report. Read [patterns/projection.md](patterns/projection.md).

## Rules

- **Default to simple mode unless the user asks for contracts or the project already has `contracts/`.**
- Do not suggest contract-first to users who just want to test an existing endpoint — that's simple mode.
- Do not jump straight into code when the user really needs a gap report or test plan first.
- If the user shifts intent mid-task (simple ↔ contract-first), re-route here.
- Prefer stable `package.json` scripts before wiring CI providers.
- When stable coverage lives in `tests/` or `contracts/`, point the user to CI next.

## Deep refs

- Promotion (simple mode only): [patterns/promotion.md](patterns/promotion.md)
- CI: [ci-workflow.md](ci-workflow.md)
- MCP: [mcp.md](mcp.md)
