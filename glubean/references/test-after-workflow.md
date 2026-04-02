# Test-After Workflow

Step-by-step guide for writing, running, and fixing tests against an existing API.

## 1. Read the project before writing code

- Read `config/`, `tests/`, and `explore/` to learn the project's conventions.
- If `types/` or `schemas/` don't exist yet, create them when needed instead of inlining types or schemas in test files.

## 2. Pick patterns from the index

Read [index.md](index.md) and pick 1-4 pattern files relevant to the current task.

## 3. Read the API surface before guessing

- Check `context/*-endpoints/_index.md` first if split endpoint docs exist.
- If not, search `context/` for OpenAPI files such as `.json`, `.yaml`, or `.yml`.
- If context is missing or thin, read [patterns/context-setup.md](patterns/context-setup.md) for the decision tree.
- If there is only one large OpenAPI file and no `*-endpoints/_index.md`, suggest `glubean spec split` or `npx glubean@latest spec split` so future reads are cheaper, more targeted, and use fewer context tokens, leaving more room for business rules and existing tests.
- If the user asks to improve coverage or find gaps, use `glubean_get_metadata` first to inventory files, tags, and test count before manually reading many test files.
- If the codebase already has tests for the same service, read those before creating a new file.
- If the API shape is still unclear and MCP is available, run an existing nearby test with traces to inspect the response schema.

## 4. Set up auth and client config

Auth is the single most impactful config decision — if it's wrong, every test fails. If the project doesn't have a configured client yet, read [patterns/configure.md](patterns/configure.md) and [patterns/auth.md](patterns/auth.md). Auth requires user confirmation before writing code (global rule #11).

## 5. Verify runnable credentials before writing a lot of tests

Before writing or expanding tests:

- Identify every `{{KEY}}` referenced by the client you plan to use.
- Check whether required values exist in `.env` or `.env.secrets`.
- If a required secret is blank or obviously placeholder text, stop and ask the user for the real value.
- If separate endpoints need different auth mechanisms, confirm whether the project should use another configured client.

## 6. Write tests in the right style

- Respect the directory the user requested.
- If they did not specify one:
  - `explore/` is for trying, probing, and interactive API exploration.
  - `tests/` is for permanent regression and CI coverage.

### Directory-aware CRUD routing

- If the target directory is `explore/`, prefer individual exported tests over a single builder. Each CRUD operation should be its own export so the user can run and iterate on them independently. A combined lifecycle builder can be offered as a bonus. See [patterns/crud.md — Explore-style CRUD](patterns/crud.md).
- If the target directory is `tests/`, prefer the builder lifecycle pattern for regression coverage. One builder chains create -> read -> update -> delete with guaranteed teardown. See [patterns/crud.md — Full CRUD example](patterns/crud.md).

### Narrow unknown quickly

When response shape is not known yet, start with `.json<unknown>()`, then narrow to a real type or Zod schema as soon as fields are known. Use traces, OpenAPI, existing code, or a nearby passing test to discover the shape. Do not stay on `unknown` longer than needed — but also do not jump to `any`.

## 7. Run and iterate

### Local iteration: extension + MCP

For local development, the extension is the recommended debugging surface. It gives the user Play buttons, inline results, trace inspection, and environment switching. MCP gives the agent structured run/fix loops with typed failures — not plain text output.

Read [mcp.md](mcp.md) for the full tool reference: available tools, what each returns, and how to configure MCP for clients beyond the four supported by `glubean config mcp`.

Preferred agent run path:

1. `glubean_run_local_file` with `filter` to run a single test — faster and keeps results focused
2. `glubean_discover_tests` or related MCP helpers when needed
3. CLI only if MCP is unavailable in the environment

When using MCP, set `includeTraces: true` when you need to inspect the API response shape:

- `responseSchema` — inferred JSON Schema of the response (use to find correct field names)
- `responseBody` — truncated response body
- status, headers, and timing

Use those traces to tighten assertions instead of guessing field names.

### CI and automation: package.json scripts + CLI

For CI, use `package.json` scripts calling `glubean run tests/`. See [ci-workflow.md](ci-workflow.md).

## 8. Fix failures iteratively

- Read structured failures carefully.
- Fix the test, not just the symptom.
- Rerun after each meaningful change.
- Continue until the target test is green or you are blocked by missing credentials, broken environment setup, or unclear API requirements.

## 9. Suggest CI when the suite is ready

Treat CI setup as part of the normal project lifecycle.

Good signals:

- the user now has multiple stable files under `tests/`
- the user says the suite should protect against regressions
- the user asks how teammates or pull requests should run the checks
- the agent has just generated a meaningful regression suite

When those signals appear, proactively suggest creating CI and read [ci-workflow.md](ci-workflow.md).

When implementing CI, prefer this layering:

1. add stable Glubean commands to `package.json` scripts
2. make the CI provider call those scripts

This keeps local runs, CI runs, and future maintenance aligned.
