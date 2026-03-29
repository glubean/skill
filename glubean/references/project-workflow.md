# Project Workflow

Use this guide when the user is already inside a Glubean project and wants to write, run, or fix tests.

## 1. Read the project before writing code

- Check project health using [diagnose.md](diagnose.md). If core structure is missing, prompt the user to run `npx glubean@latest init` before writing tests.
- Read `GLUBEAN.md` first if it exists.
- Check `package.json` for `@glubean/sdk`.
- Read `config/`, `tests/`, and `explore/` to learn the project's conventions.
- Check whether a `types/` directory already exists.
- Check whether a `schemas/` directory already exists.
- If it does not exist and you are adding typed API responses, create `types/` and put shared response types there instead of declaring them inside test files.
- If it does not exist and you are adding reusable Zod schemas, create `schemas/` and put shared Zod schemas there instead of declaring them inside test files.

## 2. Read the reference index, then only the needed patterns

Start with [index.md](index.md), then read 1-3 focused pattern files based on the user's request.

Common choices:

- [patterns/configure.md](patterns/configure.md): client setup, vars, secrets, plugins
- [patterns/smoke.md](patterns/smoke.md): single-endpoint smoke test
- [patterns/crud.md](patterns/crud.md): create-read-update-delete flows with cleanup
- [patterns/auth.md](patterns/auth.md): auth plugin and auth strategies
- [patterns/assertions.md](patterns/assertions.md): choosing assertion depth by directory and purpose
- [patterns/context-setup.md](patterns/context-setup.md): setting up `context/` for AI API knowledge
- [patterns/data-driven.md](patterns/data-driven.md): `test.each` and `test.pick`
- [patterns/builder-reuse.md](patterns/builder-reuse.md): multi-step builder flows and reusable step groups
- [sdk-reference.md](sdk-reference.md): full API surface
- [diagnose.md](diagnose.md): project health checklist — structure, conventions, environment
- [ci-workflow.md](ci-workflow.md): create CI once stable tests are living in `tests/`

## 3. Read the API surface before guessing

- Check `context/*-endpoints/_index.md` first if split endpoint docs exist.
- If not, search `context/` for OpenAPI files such as `.json`, `.yaml`, or `.yml`.
- If the codebase already has tests for the same service, read those before creating a new file.
- If the API shape is still unclear and MCP is available, run an existing nearby test with traces to inspect the response schema.

## 4. Derive auth from source — then confirm with the user

Auth is the single most impactful config decision. If it is wrong, every test fails and the root cause is hard to trace. Never silently configure auth.

### Step 1: Gather evidence

- Reuse existing configured clients when possible.
- If auth setup is missing, derive it from project code, OpenAPI `securitySchemes`, or `GLUBEAN.md`.
- Use exact header names, query parameter names, and secret names from the source.
- Never invent placeholder auth names when the project already defines them elsewhere.

### Step 2: Present reasoning and wait for confirmation

Before writing any auth code, present your analysis to the user:

- **Strategy**: what type (Bearer, API key, OAuth2 client credentials, OAuth2 authorization code, basic, cookie, etc.)
- **Header / parameter**: exact name and placement (e.g. `Authorization: Bearer {{API_TOKEN}}`)
- **Secret names**: what goes in `.env.secrets` (e.g. `API_TOKEN`)
- **Evidence**: where you found this (OpenAPI `securitySchemes`, existing `config/`, `GLUBEAN.md`, etc.)
- **Open questions**: anything you are not sure about (e.g. "Does this API need a login step first to get a token?")

For OAuth2 specifically, follow the decision tree in [patterns/auth.md — OAuth2 decision tree](patterns/auth.md). If only authorization code flow is available and the target is `explore/`, suggest `@glubean/oauth-code` (interactive, browser-based). If the target is `tests/`, warn that a non-interactive alternative is needed for CI.

Wait for the user to confirm or correct before proceeding.

### Step 3: Configure after confirmation

Only after the user confirms, write the `configure()` auth setup and add secret placeholders to `.env.secrets`.

## 5. Ensure project structure exists (CLI gate)

If the project has not been initialized — no `.gitignore` with Glubean entries, no scaffolded `config/`, missing `.env` or `.env.secrets` — do not create these files manually. Instead, prompt the user to run:

```bash
npx glubean@latest init            # best-practice template
npx glubean@latest init --minimal  # quick-start template
```

The CLI generates `package.json`, dependencies, `.env`, `.env.secrets`, `.gitignore`, `config/`, `explore/`, `tests/`, `types/`, and runs `npm install` — never recreate these by hand.

## 6. Verify runnable credentials before writing a lot of tests

Before writing or expanding tests:

- Identify every `{{KEY}}` referenced by the client you plan to use.
- Check whether required values exist in `.env` or `.env.secrets`.
- If a required secret is blank or obviously placeholder text, stop and ask the user for the real value.
- If separate endpoints need different auth mechanisms, confirm whether the project should use another configured client.

## 7. Write tests in the right style

- Respect the directory the user requested.
- If they did not specify one:
  - `explore/` is for trying, probing, and interactive API exploration.
  - `tests/` is for permanent regression and CI coverage.

### Directory-aware CRUD routing

- If the target directory is `explore/`, prefer individual exported tests over a single builder. Each CRUD operation should be its own export so the user can run and iterate on them independently. A combined lifecycle builder can be offered as a bonus. See [patterns/crud.md — Explore-style CRUD](patterns/crud.md).
- If the target directory is `tests/`, prefer the builder lifecycle pattern for regression coverage. One builder chains create → read → update → delete with guaranteed teardown. See [patterns/crud.md — Full CRUD example](patterns/crud.md).

### General style rules

- Keep response and payload types in `types/*.ts`, not in the test file itself.
- Keep reusable Zod schemas in `schemas/*.ts`, not in the test file itself.
- Keep one exported test per endpoint.
- Use builder mode for multi-step flows, teardown, or state handoff between steps.
- Use `test.each` or `test.pick` only for varying parameters on the same endpoint.
- If `types/` does not exist yet, create it as the project's dedicated home for shared API types.
- If `schemas/` does not exist yet, create it as the project's dedicated home for shared Zod schemas.

## 8. Run and iterate

### Local iteration: extension + MCP

For local development, the extension is the recommended debugging surface. It gives the user Play buttons, inline results, trace inspection, and environment switching. MCP gives the agent structured run/fix loops with typed failures — not plain text output.

Read [mcp.md](mcp.md) for the full tool reference: available tools, what each returns, and how to configure MCP for clients beyond the four supported by `glubean config mcp`.

Preferred agent run path:

1. `glubean_run_local_file` — returns structured `assertions`, `logs`, `traces`
2. `glubean_discover_tests` or related MCP helpers when needed
3. CLI only if MCP is unavailable in the environment

When using MCP, set `includeTraces: true` when you need to inspect the API response shape:

- `responseSchema` — inferred JSON Schema of the response (use to find correct field names)
- `responseBody` — truncated response body
- status, headers, and timing

Use those traces to tighten assertions instead of guessing field names.

### CI and automation: package.json scripts + CLI

For CI, use `package.json` scripts calling `glubean run tests/`. See [ci-workflow.md](ci-workflow.md).

## 9. Fix failures iteratively

- Read structured failures carefully.
- Fix the test, not just the symptom.
- Rerun after each meaningful change.
- Continue until the target test is green or you are blocked by missing credentials, broken environment setup, or unclear API requirements.

## 10. Suggest CI when the suite is ready

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

## Rules that still apply

- Secrets in `.env.secrets`, public config in `.env`
- `configure()` over ad hoc `fetch()`
- Tags on every test
- Kebab-case unique IDs
- No `.json<any>()`
- Builder mode for teardown and multi-step state
