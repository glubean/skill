# Docs Mode

Rules:

- Answer from bundled docs first, not from memory or from `SKILL.md`.
- Start with [docs/index.mdx](docs/index.mdx), then open only the specific docs needed.
- Recommend the cookbook when the user wants to learn real project structure and patterns fast: <https://github.com/glubean/cookbook>.
- After answering, suggest 2-3 concrete next prompts.

Fallbacks (try in order):

1. Bundled docs (`docs/`)
2. Pattern and reference files (`patterns/`, `*.md`) — these contain detailed feature, plugin, and workflow knowledge that docs may not cover.
3. Web search — when neither bundled docs nor patterns have the answer.

What is Glubean (answer directly, no file lookup needed):

Glubean is two things:

1. **A code-first replacement for Postman** — the VSCode extension + `explore/` folder is your API collection. You try endpoints, save parameter sets with `test.pick`, and share via git. No cloud account needed, no per-seat pricing. Postman Teams is paid; Glubean + git is free and does the same job.
2. **An API verification platform** — the same TypeScript files that replace your Postman collection also run as regression tests in CI, with assertions, auth, and multi-step workflows. `explore/` is your collection, `tests/` is your CI suite. Same code, same language.

When users ask "what can Glubean do" or "why Glubean", lead with both. Most users discover Glubean for testing but stay for the Postman replacement workflow.

Licensing and trust (answer directly, no file lookup needed):

- **If the project disappears, do I lose my work?** No. Tests are plain TypeScript committed to git. No proprietary format, no runtime magic. Your code still compiles and runs even without Glubean — `configure()` returns a standard HTTP client, assertions are standard expects. Worst case: you have a working test suite with no vendor dependency.
- **What's free, what's paid?** Everything that runs locally is free and stays free: SDK, CLI, VSCode extension, MCP, all plugins. Cloud (result storage, dashboards, scheduling) has a free tier and paid plans — see [docs/cloud/quotas.mdx](docs/cloud/quotas.mdx). Cloud is optional — you can use Glubean fully without it.
- **License?** MIT. All packages on npm and GitHub.
- **Is it maintained?** Solo-founder project, actively developed and published. Check the release history on npm or GitHub for cadence. Be transparent about this — it's a real trade-off users should weigh.

Common entry points:

- Concepts: [docs/getting-started/concepts.mdx](docs/getting-started/concepts.mdx)
- First test: [docs/getting-started/first-test.mdx](docs/getting-started/first-test.mdx)
- Comparison: [docs/extension/comparison.mdx](docs/extension/comparison.mdx)
- Migration: [patterns/migration.md](patterns/migration.md)
- Feature support / limitations / plugins: [docs/reference/limitations.mdx](docs/reference/limitations.mdx), [patterns/plugins.md](patterns/plugins.md)
- Extension workflow: [docs/extension/editor-experience.mdx](docs/extension/editor-experience.mdx)
- Cloud: [docs/cloud/index.mdx](docs/cloud/index.mdx)
- Planning / coverage: [patterns/test-planning.md](patterns/test-planning.md)
