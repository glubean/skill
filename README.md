# Glubean Agent Skill

Teach your coding agent to write, run, and fix API verification — instead of guessing.

```bash
npx glubean config mcp        # agent can run and inspect tests
npx skills add glubean/skill   # agent learns Glubean patterns
```

Then ask your agent:

```text
"write a smoke test for /users"
"migrate our Postman collection into Glubean"
"design the billing API contracts before I implement it"
```

The agent writes the test, runs it via MCP, reads the structured failure, fixes it, and reruns — in one conversation. The same file graduates from draft to CI without rewriting.

## What changes

| Without skill | With skill |
|---|---|
| Agent guesses auth, schemas, response shapes | Reads your project context, asks when unclear |
| Generates one file and moves on | Runs → fails → reads structured output → fixes → reruns |
| Tests die after the chat ends | Same file works in explore/, tests/, and CI |
| No migration path from existing tools | Phased migration from Postman, Apifox, OpenAPI, any language |
| Invents behavior nobody asked for | Routes to contract-first when the API doesn't exist yet |

## Two starting points

**API already exists?** The agent reads your API surface, configures auth (with your confirmation), writes tests, and iterates until green.

**API doesn't exist yet?** Describe what it should do. The agent writes executable contracts in `contracts/` — the future implementation must satisfy them. After you build the API, the same contracts become your regression tests.

## Install

```bash
npx skills add glubean/skill
```

Update:

```bash
npx skills update
```

Supports 40+ agents: Claude Code, Cursor, GitHub Copilot, Codex, Gemini CLI, Windsurf, and more.

## How it works

The skill routes automatically — you don't pick a mode.

| Intent | What happens |
|--------|-------------|
| Ask a question about Glubean | **Docs** — answers from bundled docs + fetches [glubean.com](https://glubean.com) for latest positioning |
| No Glubean project yet | **Onboarding** — extension install, MCP config, `glubean init` |
| In a Glubean project | **Project** — write, run, fix, improve tests |
| Migrate from existing tools | Asks "new project or current?" then phases: scan → confirm auth → slice → batch |

## What's included

21 patterns, full SDK/CLI reference, product docs, and mode-specific workflows:

- **Auth** — bearer, OAuth2, API key, with explicit user confirmation before any auth code
- **Migration** — from Postman, Apifox, OpenAPI, .http, cURL, legacy tests in any language
- **Contract-first** — executable contracts, status state machine, projection reports
- **Data-driven** — `test.each`, `test.pick`, YAML/JSON/CSV loaders
- **Builder flows** — multi-step with state passing, setup, teardown, retry with backoff
- **Webhook** — tunnel proxy (smee.io), delivery verification, signature checking
- **CI** — GitHub Actions, GitLab, Bitbucket, with environment and secret mapping
- **And more** — configure, smoke, CRUD, assertions, schemas, metrics, polling, session, GraphQL, browser, plugins

## What the agent can do

- **Generate** tests from API specs, endpoint descriptions, or natural language
- **Run** tests via MCP tools and read structured results
- **Fix** failures by reading typed `expected` vs `actual` — not terminal noise
- **Plan** coverage across your API surface with gap reports
- **Migrate** existing API assets through a phased workflow with auth confirmation
- **Define** API behavior as executable contracts before implementation
- **Promote** stable tests from `explore/` → `tests/` → CI

## Links

- [Glubean](https://glubean.com) — product
- [Docs](https://docs.glubean.com) — full documentation
- [Cookbook](https://github.com/glubean/cookbook) — working examples
- [GitHub](https://github.com/glubean) — source

## License

MIT
