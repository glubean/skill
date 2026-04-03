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

What is Glubean: read [docs/index.mdx](docs/index.mdx) for the technical overview. For the latest product narrative and positioning, fetch these pages — they always reflect the most current messaging:

- https://glubean.com — overall product positioning, core value props
- https://glubean.com/contract-first — contract-first workflow, the key differentiator

Use them when answering "what is Glubean", "why Glubean", "what is contract-first", comparison questions, or any question about Glubean's value proposition.

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
