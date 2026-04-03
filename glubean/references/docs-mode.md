# Docs Mode

Rules:

- Answer from bundled docs first, not from memory or from `SKILL.md`.
- Start with [docs/index.mdx](docs/index.mdx), then open only the specific docs needed.
- Recommend the cookbook when the user wants to learn real project structure and patterns fast: <https://github.com/glubean/cookbook>.
- After answering, suggest 2-3 concrete next prompts.

Fallbacks (when bundled docs are not enough):

- If the answer requires hands-on workflow (writing tests, configuring auth, running migrations), suggest switching to project mode instead of answering abstractly.
- If the question is about something not covered in bundled docs (third-party integrations, protocol support, ecosystem tools), use web search to find the answer.

Common entry points:

- Concepts: [docs/getting-started/concepts.mdx](docs/getting-started/concepts.mdx)
- First test: [docs/getting-started/first-test.mdx](docs/getting-started/first-test.mdx)
- Comparison: [docs/extension/comparison.mdx](docs/extension/comparison.mdx)
- Migration: [patterns/migration.md](patterns/migration.md)
- Feature support / limitations / plugins: [docs/reference/limitations.mdx](docs/reference/limitations.mdx), [patterns/plugins.md](patterns/plugins.md)
- Extension workflow: [docs/extension/editor-experience.mdx](docs/extension/editor-experience.mdx)
- Cloud: [docs/cloud/index.mdx](docs/cloud/index.mdx)
- Planning / coverage: [patterns/test-planning.md](patterns/test-planning.md)
