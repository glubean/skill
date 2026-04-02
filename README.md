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

That's it. The skill routes the agent into the right workflow automatically. For `glubean init`, the skill expects the user to run the interactive CLI themselves.

Supports 40+ agents including Claude Code, Cursor, GitHub Copilot, Codex, Gemini CLI, Windsurf, and more.

## Modes

The skill operates in three modes. You don't need to pick one — the agent routes based on your intent and project state.

| Mode | When it activates | What the agent does |
|------|------------------|---------------------|
| **Docs** | You ask a question, no active task | Answers from bundled docs — concepts, comparison, migration, extension, cloud |
| **Onboarding** | No Glubean project yet | Guides extension install, MCP config, `glubean init`, cookbook |
| **Project** | You're in a Glubean project | Writes, runs, fixes, and improves tests |

### Project sub-routes

Inside Project mode, the agent picks one of two paths based on whether the API already exists:

| Sub-route | When | What the agent does |
|-----------|------|---------------------|
| **Test-after** | API is already running and callable | Read API surface, configure auth, write tests, run via MCP, iterate until green, suggest CI |
| **Contract-first** | API doesn't exist yet | Capture intent in `product/`, write executable contracts in `contracts/`, implement, promote to `tests/` |

## What's included

```
glubean/
├── SKILL.md                        # Thin router: mode selection, intent examples, global rules
└── references/
    ├── docs-mode.md                # Docs mode entry
    ├── onboarding.md               # Onboarding mode entry
    ├── project-mode.md             # Project mode entry (test-after / contract-first)
    ├── contract-first.md           # Contract-first sub-route entry
    ├── test-after-workflow.md      # Step-by-step test-after workflow
    ├── diagnose.md                 # Project health checklist
    ├── index.md                    # Pattern & capability index
    ├── mcp.md                      # MCP tools reference & agent run loop
    ├── ci-workflow.md              # CI setup guide
    ├── sdk-reference.md            # Full SDK API reference
    ├── cli-reference.md            # CLI command reference
    ├── docs/                       # Full product documentation
    └── patterns/                   # 21 per-topic guides
        ├── configure.md            # Shared clients, env, secrets, plugins
        ├── auth.md                 # Auth strategies (bearer, OAuth2, apiKey...)
        ├── multi-env.md            # Multi-environment setup & ${HOST_VAR} passthrough
        ├── smoke.md, crud.md, data-driven.md, builder-reuse.md
        ├── contract-first.md, test-planning.md, promotion.md
        └── ...
```

## What it does

Once installed, your AI coding agent can:

- **Onboard** a real Glubean setup (extension, MCP, cookbook, project init)
- **Generate** test files from API specs, endpoint descriptions, or natural language
- **Run** tests via MCP tools or CLI (`npx glubean run`)
- **Fix** failing tests by reading structured failure output and iterating
- **Plan** test coverage systematically across your API surface
- **Define** API behavior as executable contracts before implementation
- **Learn** SDK patterns on demand from bundled reference docs

## License

MIT
