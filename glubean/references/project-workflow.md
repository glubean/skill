# Project Workflow

Use this guide when the user is already inside a Glubean project and wants to write, run, or fix tests.

## 1. Read the project before writing code

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
- [patterns/data-driven.md](patterns/data-driven.md): `test.each` and `test.pick`
- [patterns/builder-reuse.md](patterns/builder-reuse.md): multi-step builder flows and reusable step groups
- [sdk-reference.md](sdk-reference.md): full API surface
- [ci-workflow.md](ci-workflow.md): create CI once stable tests are living in `tests/`

## 3. Read the API surface before guessing

- Check `context/*-endpoints/_index.md` first if split endpoint docs exist.
- If not, search `context/` for OpenAPI files such as `.json`, `.yaml`, or `.yml`.
- If the codebase already has tests for the same service, read those before creating a new file.
- If the API shape is still unclear and MCP is available, run an existing nearby test with traces to inspect the response schema.

## 4. Derive auth from source, not placeholders

- Reuse existing configured clients when possible.
- If auth setup is missing, derive it from project code, OpenAPI `securitySchemes`, or `GLUBEAN.md`.
- Use exact header names, query parameter names, and secret names from the source.
- Never invent placeholder auth names when the project already defines them elsewhere.

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
- Keep response and payload types in `types/*.ts`, not in the test file itself.
- Keep reusable Zod schemas in `schemas/*.ts`, not in the test file itself.
- Keep one exported test per endpoint.
- Use builder mode for multi-step flows, teardown, or state handoff between steps.
- Use `test.each` or `test.pick` only for varying parameters on the same endpoint.
- If `types/` does not exist yet, create it as the project's dedicated home for shared API types.
- If `schemas/` does not exist yet, create it as the project's dedicated home for shared Zod schemas.

## 7. Run with MCP first

Preferred run path:

1. `glubean_run_local_file`
2. `glubean_discover_tests` or related MCP helpers when needed
3. CLI only if MCP is unavailable in the environment

When using MCP, include traces when useful so you can inspect:

- `responseSchema`
- `responseBody`
- status, headers, and timing

Use those traces to tighten assertions instead of guessing field names.

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

## Rules that still apply

- Secrets in `.env.secrets`, public config in `.env`
- `configure()` over ad hoc `fetch()`
- Tags on every test
- Kebab-case unique IDs
- No `.json<any>()`
- Builder mode for teardown and multi-step state
