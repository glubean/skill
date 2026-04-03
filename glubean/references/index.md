# Glubean Reference Index

Quick lookup for AI agents. Read one mode guide first, then only the references you actually need.

## Modes

| Mode | Read first |
|------|------------|
| Docs | [docs-mode.md](docs-mode.md) |
| Onboarding | [onboarding.md](onboarding.md) |
| Project | [project-mode.md](project-mode.md) — routes to test-after or contract-first |

## Core refs

| File | Use when needed |
|------|------------------|
| [diagnose.md](diagnose.md) | Check project health and structure |
| [test-after-workflow.md](test-after-workflow.md) | Step-by-step test-after writing workflow |
| [mcp.md](mcp.md) | Configure MCP or understand MCP tool behavior |
| [ci-workflow.md](ci-workflow.md) | Wire stable tests into CI |
| [sdk-reference.md](sdk-reference.md) | Look up SDK API details |
| [cli-reference.md](cli-reference.md) | Look up CLI commands |

## Common patterns

| File | Use when needed |
|------|------------------|
| [patterns/configure.md](patterns/configure.md) | Shared client, env, secrets, plugins |
| [patterns/contract-first.md](patterns/contract-first.md) | Full contract authoring workflow |
| [patterns/projection.md](patterns/projection.md) | Contract coverage report: product → contract → test alignment |
| [patterns/test-planning.md](patterns/test-planning.md) | Coverage planning and gap reports |
| [patterns/migration.md](patterns/migration.md) | Migrate from Postman, Apifox, OpenAPI, `.http`, cURL, or legacy test code |
| [patterns/promotion.md](patterns/promotion.md) | Promote `explore/` or `contracts/` work into `tests/` |
| [patterns/context-setup.md](patterns/context-setup.md) | Set up `context/` and `GLUBEAN.md` for better generation |
| [patterns/smoke.md](patterns/smoke.md) | Single-endpoint smoke coverage |
| [patterns/crud.md](patterns/crud.md) | CRUD lifecycle coverage |
| [patterns/data-driven.md](patterns/data-driven.md) | `test.each` and `test.pick` workflows |
| [patterns/builder-reuse.md](patterns/builder-reuse.md) | Reusable builder step sequences |
| [patterns/session.md](patterns/session.md) | Cross-file shared state and workflow reuse |
| [patterns/assertions.md](patterns/assertions.md) | Assertion depth |
| [patterns/errors.md](patterns/errors.md) | Negative-path coverage |
| [patterns/schema.md](patterns/schema.md) | Zod schema validation |
| [patterns/polling.md](patterns/polling.md) | Async jobs and eventual consistency |
| [patterns/webhook.md](patterns/webhook.md) | Webhook delivery testing: tunnel, verify, cleanup |
| [patterns/metrics.md](patterns/metrics.md) | Custom metrics and performance tracking |
| [patterns/auth.md](patterns/auth.md) | Auth strategies after user confirmation |
| [patterns/graphql.md](patterns/graphql.md) | GraphQL testing |
| [patterns/browser.md](patterns/browser.md) | Browser testing |
| [patterns/plugins.md](patterns/plugins.md) | Plugin index: `@glubean/auth`, `@glubean/browser`, `@glubean/graphql`, `@glubean/oauth-code` |
| [patterns/multi-env.md](patterns/multi-env.md) | Multi-environment setup: env files, `${HOST_VAR}` passthrough, switching |
| [patterns/bootstrap.md](patterns/bootstrap.md) | Project init wizard details and setup sequence |

## Product docs

Use [docs/index.mdx](docs/index.mdx) as the landing page when the mode guides and references above are not enough.

## Notes

- Hard rules live in [../SKILL.md](../SKILL.md).
- Keep reads shallow: mode guide first, then only the next file that answers the current question.
