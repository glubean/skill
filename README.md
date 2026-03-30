# Glubean Agent Skill

[Agent Skill](https://agentskills.io) for [Glubean](https://glubean.com) — generate, run, and fix API tests with any AI coding agent.

## Install

```bash
npx skills add glubean/skill
```

### Update

```bash
npx skills update
```

That's it. On first use, the agent can guide the user through Glubean setup, project init, and MCP configuration using the bundled bootstrap workflow. For `glubean init`, the skill expects the user to run the interactive CLI themselves.

Supports 40+ agents including Claude Code, Cursor, GitHub Copilot, Codex, Gemini CLI, Windsurf, and more.

## What's included

```
glubean/
├── SKILL.md                    # Agent instructions
└── references/
    ├── index.md                # Pattern & capability index
    ├── sdk-reference.md        # Full SDK API reference
    ├── cli-reference.md        # CLI command reference
    └── patterns/               # Per-topic guides
        ├── auth.md, bootstrap.md, configure.md
        ├── crud.md, data-driven.md, builder-reuse.md
        └── ...
```

## What it does

Once installed, your AI coding agent can:

- **Bootstrap** a new Glubean project (guide SDK setup, init, and MCP configuration)
- **Generate** test files from API specs, endpoint descriptions, or natural language
- **Run** tests via MCP tools or CLI (`npx glubean run`)
- **Fix** failing tests by reading structured failure output and iterating
- **Learn** SDK patterns on demand from bundled reference docs

## License

MIT
