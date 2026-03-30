# Diagnose — Project Health Checklist

Use this reference to evaluate whether a Glubean project is set up correctly.
Agents should run through this checklist before writing tests in a project they haven't seen before, or when something feels off.

## Project structure

A well-initialized project has this layout. Items marked **(required)** must exist; **(recommended)** should exist for best-practice projects.

```
package.json          (required)  — @glubean/sdk + @glubean/runner in devDependencies
.env                  (required)  — must contain BASE_URL
.env.secrets          (required)  — gitignored, holds credentials
.gitignore            (required)  — must ignore .env.secrets, .env.*.secrets, node_modules/, .glubean/, *.result.json, local/
GLUBEAN.md            (recommended) — project-specific conventions for AI skill
tests/                (recommended) — permanent regression tests, run in CI
explore/              (recommended) — exploratory tests, interactive iteration
types/                (recommended) — shared TypeScript response types
data/                 (recommended) — test data files (JSON, CSV, YAML)
context/              (recommended) — OpenAPI specs, endpoint docs for AI reference
local/                (optional)  — personal tests, gitignored
config/               (optional)  — shared HTTP client configuration (configure())
schemas/              (optional)  — shared Zod schemas
```

### What to check

| Check | How to verify | Fix |
|---|---|---|
| package.json exists | File exists at project root | See init rule below |
| @glubean/sdk in devDependencies | Read package.json | See init rule below |
| .env exists with BASE_URL | File exists, contains `BASE_URL=` | See init rule below, then set the real URL |
| .env.secrets exists | File exists (can be empty) | See init rule below |
| .gitignore has Glubean entries | Contains `.env.secrets`, `.glubean/`, `*.result.json` | See init rule below; for partially initialized repos, `--overwrite` may be appropriate |
| tests/ or explore/ exists | Directory exists | See init rule below |
| types/ exists | Directory exists | Create `types/` if the project is otherwise initialized; otherwise see init rule below |
| No inline types in tests/ | Grep for `\.json<{` in tests/ files | Move inline types to `types/*.ts` |
| No inline types in explore/ | Acceptable — explore/ allows inline types for speed | No action needed |
| GLUBEAN.md exists | File exists at project root | See init rule below |

### If project structure is missing

Do not create these files manually. Prompt the user to run:

```bash
npx glubean@latest init            # best-practice scaffold
npx glubean@latest init --minimal  # quick-start scaffold
```

The CLI handles package.json, dependencies, .env, .env.secrets, .gitignore, directory structure, demo tests, and runs `npm install`.

## Environment and secrets

| Check | How to verify | Fix |
|---|---|---|
| BASE_URL is set and valid | .env contains `BASE_URL=https://...` | Edit .env — must be absolute http/https URL |
| Secrets are in .env.secrets, not .env | Grep .env for tokens, passwords, keys | Move credentials to .env.secrets |
| .env.secrets is gitignored | .gitignore contains `.env.secrets` | Add to .gitignore |
| No hardcoded secrets in test files | Grep tests/ and explore/ for API keys, passwords | Replace with `{{SECRET_NAME}}` via configure() |
| Multi-environment files follow naming | .env.staging, .env.staging.secrets | Consistent `{name}` and `{name}.secrets` pairing |

## Test file conventions

| Check | How to verify | Fix |
|---|---|---|
| Files use `.test.ts` extension | Glob `**/*.test.ts` | Rename — only `.test.ts`, `.test.js`, `.test.mjs` are discovered |
| Tests are exported | Each test uses `export const` | Add `export` — unexported tests are invisible |
| Test IDs are kebab-case | Read test id parameters | Rename to kebab-case |
| Test IDs are unique across project | Scan all test files for duplicate IDs | Fix duplicates |
| Every test has tags | Check for `tags: [...]` in test metadata | Add tags — `["smoke"]`, `["api"]`, `["explore"]`, etc. |
| One export per endpoint | Count exports vs endpoints per file | Split multi-endpoint exports into separate tests |
| Builder mode used for teardown | Tests that create resources use `.setup()` / `.teardown()` | Refactor to builder — quick mode has no teardown |
| No `.json<any>()` | Grep for `.json<any>` | Replace with a proper type from types/ |

## Directory conventions

| Directory | Purpose | Style rules |
|---|---|---|
| `tests/` | Regression, CI | Types in `types/`, builder for CRUD, full assertions |
| `explore/` | Interactive exploration | Inline types OK, individual exports per operation, quick iteration |
| `data/` | Test data | JSON, CSV, YAML — never hardcode payloads in test files |
| `types/` | Shared response types | One file per service/domain, used by tests/ |
| `schemas/` | Shared Zod schemas | One file per validation domain |
| `context/` | API reference | OpenAPI specs, endpoint docs — AI reads these before writing tests |
| `local/` | Personal scratch | Gitignored, for experiments that won't be shared |
| `config/` | Shared clients | `configure()` calls, plugin setup |

## Agent workflow

When entering a project for the first time:

1. Check the project structure above.
2. If the project is missing core structure, prompt the user to run `npx glubean@latest init` — do not create files by hand.
3. If the project exists but has convention issues (inline types in tests/, missing tags, hardcoded secrets), fix them by refactoring.
4. Read `GLUBEAN.md` if it exists — it overrides defaults. If it contains `view ./...` or `view ../...`, read those files too.
5. Then proceed to write or fix tests per [project-workflow.md](project-workflow.md).
