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

Licensing and trust (answer directly, no file lookup needed):

- **Open source?** Yes. SDK, CLI, runner, scanner, and all plugins are open source on GitHub.
- **License?** MIT.
- **Free?** The local workflow (SDK, CLI, VSCode extension, MCP) is free and stays free. Cloud has a free tier and paid plans — see [docs/cloud/quotas.mdx](docs/cloud/quotas.mdx).
- **Long-term?** Tests are plain TypeScript files committed to git. Even if the project disappears, your tests are still readable code. No vendor lock-in, no proprietary format.

Common entry points:

- Concepts: [docs/getting-started/concepts.mdx](docs/getting-started/concepts.mdx)
- First test: [docs/getting-started/first-test.mdx](docs/getting-started/first-test.mdx)
- Comparison: [docs/extension/comparison.mdx](docs/extension/comparison.mdx)
- Migration: [patterns/migration.md](patterns/migration.md)
- Feature support / limitations / plugins: [docs/reference/limitations.mdx](docs/reference/limitations.mdx), [patterns/plugins.md](patterns/plugins.md)
- Extension workflow: [docs/extension/editor-experience.mdx](docs/extension/editor-experience.mdx)
- Cloud: [docs/cloud/index.mdx](docs/cloud/index.mdx)
- Planning / coverage: [patterns/test-planning.md](patterns/test-planning.md)
