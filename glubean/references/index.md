# Glubean Lens Index

Quick lookup for AI agents. Read this first, then open only the files you need.

## Modes

Use this index after you know which mode you are in:

| Mode | When to use | Read first |
|------|-------------|------------|
| Docs | The user has only the skill and is asking product or documentation questions | `references/docs/...` files listed below |
| Bootstrap | The user has only the skill and wants a first demo, install, or setup flow | [patterns/bootstrap.md](patterns/bootstrap.md) |
| Project | The user is already in a Glubean project and wants test work | [project-workflow.md](project-workflow.md) |

## Reference

| File | When to read |
|------|-------------|
| [sdk-reference.md](sdk-reference.md) | Need full API surface — test(), ctx, expect, HTTP client, data loading |
| [cli-reference.md](cli-reference.md) | Need to run, filter, upload, or init a project |
| [mcp.md](mcp.md) | Configure MCP for any client; available tools; why MCP > CLI for agents |
| [ci-workflow.md](ci-workflow.md) | Need to wire stable tests into CI or create a CI workflow |
| [diagnose.md](diagnose.md) | Need to check project health, structure, or conventions before writing tests |

## Patterns

| File | When to use |
|------|------------|
| [configure.md](patterns/configure.md) | Setting up HTTP client, env vars, secrets, plugins — **read this first for any new project** |
| [smoke.md](patterns/smoke.md) | Simple single-endpoint health/smoke test |
| [crud.md](patterns/crud.md) | Create → Read → Update → Delete with setup/teardown cleanup |
| [builder-reuse.md](patterns/builder-reuse.md) | Multi-step builder, `.use()` / `.group()` for reusable step sequences |
| [data-driven.md](patterns/data-driven.md) | `test.each` (one file = one case) and `test.pick` (named cases, merged files) |
| [errors.md](patterns/errors.md) | Negative tests — 401, 403, 404, 422 |
| [polling.md](patterns/polling.md) | Async jobs, `pollUntil`, eventual consistency |
| [schema.md](patterns/schema.md) | Zod schema validation on API responses |
| [metrics.md](patterns/metrics.md) | Custom performance metrics, duration tracking |
| [session.md](patterns/session.md) | Cross-file shared state via `defineSession()` + `ctx.session` (auth token reuse, workflow chains) |
| [browser.md](patterns/browser.md) | Browser testing — setup, navigation, forms, scraping, dynamic elements |

## Plugins

| File | When to use |
|------|------------|
| [plugins.md](patterns/plugins.md) | Plugin index — **check here before writing auth/plugin code by hand** |
| [auth.md](patterns/auth.md) | `@glubean/auth` — bearer, apiKey, basic, OAuth2, withLogin, combining strategies |

## Documentation

Full product docs. Read when the patterns/reference above aren't enough.

### Getting Started

| File | Topic |
|------|-------|
| [docs/getting-started/installation.mdx](docs/getting-started/installation.mdx) | Install SDK, CLI, extension |
| [docs/getting-started/first-test.mdx](docs/getting-started/first-test.mdx) | Write and run your first test |
| [docs/getting-started/concepts.mdx](docs/getting-started/concepts.mdx) | Core concepts (test, configure, ctx) |
| [docs/getting-started/ci.mdx](docs/getting-started/ci.mdx) | CI/CD integration |
| [docs/getting-started/upload-to-cloud.mdx](docs/getting-started/upload-to-cloud.mdx) | Upload results to Glubean Cloud |

### SDK

| File | Topic |
|------|-------|
| [docs/sdk/test-api.mdx](docs/sdk/test-api.mdx) | test(), test.each, test.pick, builder API |
| [docs/sdk/http-client.mdx](docs/sdk/http-client.mdx) | HTTP client, request/response, typed JSON |
| [docs/sdk/configuration.mdx](docs/sdk/configuration.mdx) | configure(), clients, plugins |
| [docs/sdk/assertions.mdx](docs/sdk/assertions.mdx) | ctx.expect, status, headers, body |
| [docs/sdk/data-driven.mdx](docs/sdk/data-driven.mdx) | Data files, YAML/JSON loading, test.pick |
| [docs/sdk/env-and-secrets.mdx](docs/sdk/env-and-secrets.mdx) | .env, .env.secrets, {{VAR}} references |
| [docs/sdk/local-data.mdx](docs/sdk/local-data.mdx) | fromJson, fromYaml, fromJson.map, fromYaml.map |
| [docs/sdk/shared-state.mdx](docs/sdk/shared-state.mdx) | defineSession, ctx.session |
| [docs/sdk/test-control.mdx](docs/sdk/test-control.mdx) | skip, only, timeout, retry |
| [docs/sdk/observability.mdx](docs/sdk/observability.mdx) | ctx.log, ctx.metric, traces |
| [docs/sdk/plugins.mdx](docs/sdk/plugins.mdx) | Plugin system overview |
| [docs/sdk/auth-plugin.mdx](docs/sdk/auth-plugin.mdx) | @glubean/auth plugin |
| [docs/sdk/browser-plugin.mdx](docs/sdk/browser-plugin.mdx) | @glubean/browser plugin |
| [docs/sdk/graphql-plugin.mdx](docs/sdk/graphql-plugin.mdx) | @glubean/graphql plugin |

### CLI

| File | Topic |
|------|-------|
| [docs/cli/reference.mdx](docs/cli/reference.mdx) | All CLI commands |
| [docs/cli/environments.mdx](docs/cli/environments.mdx) | Environment profiles |
| [docs/cli/recipes.mdx](docs/cli/recipes.mdx) | Common CLI workflows |
| [docs/cli/debugging.mdx](docs/cli/debugging.mdx) | Debug test runs |
| [docs/cli/redaction.mdx](docs/cli/redaction.mdx) | Redact secrets from results |
| [docs/cli/result-files.mdx](docs/cli/result-files.mdx) | Result file format |

### VS Code Extension

| File | Topic |
|------|-------|
| [docs/extension/quick-start.mdx](docs/extension/quick-start.mdx) | Extension quick start |
| [docs/extension/writing-tests.mdx](docs/extension/writing-tests.mdx) | Writing tests in VS Code |
| [docs/extension/running-tests.mdx](docs/extension/running-tests.mdx) | Running tests (Play buttons, CodeLens) |
| [docs/extension/environments.mdx](docs/extension/environments.mdx) | Environment switching |
| [docs/extension/result-viewer.mdx](docs/extension/result-viewer.mdx) | Result viewer panel |
| [docs/extension/editor-experience.mdx](docs/extension/editor-experience.mdx) | Editor features (pin, refactor, data) |
| [docs/extension/generate-with-ai.mdx](docs/extension/generate-with-ai.mdx) | AI test generation |
| [docs/extension/debugging.mdx](docs/extension/debugging.mdx) | Debugging tests |
| [docs/extension/diagnostics.mdx](docs/extension/diagnostics.mdx) | Diagnostics & troubleshooting |
| [docs/extension/comparison.mdx](docs/extension/comparison.mdx) | Glubean vs Postman/Thunder Client |
| [docs/extension/migrate-from-postman.mdx](docs/extension/migrate-from-postman.mdx) | Migrate from Postman |
| [docs/extension/for-qa-teams.mdx](docs/extension/for-qa-teams.mdx) | Guide for QA teams |
| [docs/extension/reference.mdx](docs/extension/reference.mdx) | Extension settings reference |

### Cloud

| File | Topic |
|------|-------|
| [docs/cloud/dashboard.mdx](docs/cloud/dashboard.mdx) | Cloud dashboard |
| [docs/cloud/analytics.mdx](docs/cloud/analytics.mdx) | Test analytics |
| [docs/cloud/tokens.mdx](docs/cloud/tokens.mdx) | API tokens |
| [docs/cloud/notifications.mdx](docs/cloud/notifications.mdx) | Notifications |
| [docs/cloud/redaction.mdx](docs/cloud/redaction.mdx) | Cloud redaction |
| [docs/cloud/quotas.mdx](docs/cloud/quotas.mdx) | Usage quotas |

### Blog

| File | Topic |
|------|-------|
| [docs/blog/why-i-replaced-postman-with-a-typescript-workflow-in-vscode.mdx](docs/blog/why-i-replaced-postman-with-a-typescript-workflow-in-vscode.mdx) | Why TypeScript tests beat Postman |

## Notes

- Hard rules live in [../SKILL.md](../SKILL.md).
- This file is the navigation hub: read the mode-specific guide first, then only the references needed for the task.
