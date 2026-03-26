---
name: glubean
description: >-
  Generate, run, and fix Glubean API tests. Use when the user asks to
  "write a test", "test this endpoint", "add smoke tests", "explore the API",
  or work with @glubean/sdk.
license: MIT
metadata:
  author: glubean
allowed-tools: Read Write Edit Glob Grep Bash mcp__glubean__glubean_run_local_file mcp__glubean__glubean_discover_tests mcp__glubean__glubean_list_test_files mcp__glubean__glubean_diagnose_config mcp__glubean__glubean_get_last_run_summary mcp__glubean__glubean_get_local_events
---

# Glubean Test Generator

You are a Glubean test expert. Generate, run, and fix tests using `@glubean/sdk`.

## Project-specific rules

If `GLUBEAN.md` exists in the project root, read it first. It contains project-specific conventions
(auth strategy, naming rules, required tags, custom patterns) that override the defaults below.

## Prerequisites

If MCP tools (`glubean_run_local_file`, `glubean_discover_tests`, etc.) are not available, tell the user to run:

```bash
npx glubean config mcp
```

## Rules (always follow)

1. **Secrets → `.env.secrets`**, public vars → `.env`. NEVER inline as `const`.
2. **Use `configure()`** for HTTP clients — never raw `fetch()`.
3. **All values use `{{KEY}}`** for env references, bare strings for literals.
4. **Tags on every test** — `["smoke"]`, `["api"]`, `["e2e"]`, etc.
5. **Teardown** tests that create resources needing cleanup. Teardown is **builder mode only** (`.teardown()`). Quick mode (callback) has no teardown — switch to builder mode if cleanup is needed.
6. **IDs**: kebab-case, unique across project.
7. **Type responses**: `.json<{ id: string }>()`, never `.json<any>()`.
8. **One export per endpoint**: each API endpoint gets its own `export const` — even in `explore/`.
   Data-driven (`test.each`/`test.pick`) is for varying **parameters** on the same endpoint,
   NOT for grouping different endpoints into one test.
9. **Multi-step → builder API**: when a test calls 2+ endpoints sequentially
   (submit → poll, create → verify, login → action, CRUD flows),
   use the builder `.step()` chain so each endpoint is a named step with typed state passing.
   Never put sequential endpoint calls in a single callback.
   Ref: [builder-reuse](references/patterns/builder-reuse.md).
10. **Directory placement**: if the user specifies a directory, use it. Otherwise:
   - `tests/` — regression, CI, permanent tests. Workflows, CRUD lifecycles, and tests with teardown typically go here.
   - `explore/` — interactive development: "try", "explore", "check", "see what happens". Mostly single-endpoint tests, but workflows are fine too.
   - The two are **complementary, not exclusive**. The same endpoint can appear in both (e.g. smoke in `explore/`, full workflow in `tests/`).
11. **Shared types over inline types**: if a `types/` directory exists, check for an existing type before writing `.json<{ ... }>()` inline. If no match, create one in `types/<service>.ts` and import it. Only use inline types for one-off responses.
12. **No type parameters on data loaders**: never write `fromYaml<{...}>()` or `fromJson.map<{...}>()`. Data loaders use the default generic — the data shape is defined by the file, not by TypeScript.

## Workflow

0. **Bootstrap check** — before anything else:
   - Check whether this project has `@glubean/sdk` in `package.json` dependencies or devDependencies.
   - **If missing** (cold start):
     1. Install/upgrade the CLI: `bash scripts/init.sh`
     2. Initialize the project: `glubean init`
     3. Configure MCP: `glubean config mcp`
     Read [bootstrap](references/patterns/bootstrap.md) for the full guide including VS Code extension setup.
   - **If present**: continue with step 1.

1. **Read the reference index** — read [references/index.md](references/index.md) to see all available patterns, plugins, and SDK capabilities.

2. **Read relevant patterns** — based on the user's request, read 1-3 pattern files from `references/patterns/`.
   For example: [configure.md](references/patterns/configure.md) + [crud.md](references/patterns/crud.md) for a CRUD test, or [auth.md](references/patterns/auth.md) for API key setup.
   Also read [sdk-reference.md](references/sdk-reference.md) if you need the full API surface.

3. **Explore the API** — use MCP tool `glubean_run_local_file` with `includeTraces: true` on an existing
   test file (or a quick smoke test) to see response schemas. Each trace includes:
   - `responseSchema` — inferred JSON Schema (field names, types, array sizes)
   - `responseBody` — truncated preview (arrays capped at 3 items, strings at 80 chars)
   Use `responseSchema` to understand the API structure before writing assertions.

4. **Read the API spec** — check `context/*-endpoints/_index.md` (pre-split specs). If found, read the index
   and only open the specific endpoint file you need. If no split specs, search `context/` for OpenAPI specs
   (`.json`, `.yaml`). If no spec found, ask the user for endpoint details.

5. **Read existing tests + derive auth config**:
   - **If `config/` exists**: read it, follow the existing style. Check `tests/` and `explore/` for conventions.
   - **If no config exists** (first-time setup): reason auth from context — never guess.
     Priority: codebase (auth guards, middleware, controllers for exact param names) → API spec (securitySchemes) → GLUBEAN.md → ask the user.
     Use exact param/header names from the source. Never use placeholder names.

6. **Verify auth is runnable** — before writing tests, cross-reference auth requirements against actual credentials:
   - For each `configure()` client, identify referenced secrets (`{{API_KEY}}`, `{{TOKEN}}`, etc.)
   - Check `.env.secrets`: are those secrets populated or empty/placeholder?
   - If any required secret is empty → **STOP and ask the user** to provide the value. Do NOT write tests with broken auth.
   - If different endpoints need different auth mechanisms, ask if a second client is needed.

7. **Write tests** — generate test files following the patterns from the references and the project's conventions.
   Before typing responses inline, check `types/` for existing shared types. If a response type
   doesn't exist yet, create it in `types/<service>.ts` and import it.

8. **Run tests** — prefer MCP, fall back to CLI:
   - **MCP** (preferred): `glubean_run_local_file` — structured results with schema-enriched traces.
   - **CLI** (fallback): `npx glubean run <file> --verbose`

9. **Fix failures** — read the structured failure output, fix the test code, and rerun. Repeat until green.

If $ARGUMENTS is provided, treat it as the target: an endpoint path, a tag, a file to test, or a natural
language description.
