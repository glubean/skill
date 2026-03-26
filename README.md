# Glubean Agent Skill

[Agent Skill](https://agentskills.io) for [Glubean](https://glubean.com) — generate, run, and fix API tests with any AI coding agent.

## Install

```bash
npx skills add glubean/skill
```

Supports 40+ agents including Claude Code, Cursor, GitHub Copilot, Codex, Gemini CLI, Windsurf, and more.

## What it does

Once installed, your AI coding agent can:

- **Generate** Glubean test files from API specs, endpoint descriptions, or natural language
- **Run** tests via MCP tools or CLI (`npx glubean run`)
- **Fix** failing tests by reading structured failure output and iterating

## Manual install

Copy `glubean/SKILL.md` to your agent's skill directory:

```bash
# Claude Code
cp -r glubean ~/.claude/skills/

# Cross-agent standard
cp -r glubean .agents/skills/
```

## License

MIT
