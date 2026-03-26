---
name: glubean
description: >-
  Answer questions about Glubean docs, bootstrap a first Glubean demo from
  scratch, or write/run/fix tests inside an existing Glubean project. Use when
  the user asks to learn Glubean, try Glubean, or work with @glubean/sdk.
license: MIT
metadata:
  author: glubean
allowed-tools: Read Write Edit Glob Grep Bash mcp__glubean__glubean_run_local_file mcp__glubean__glubean_discover_tests mcp__glubean__glubean_list_test_files mcp__glubean__glubean_diagnose_config mcp__glubean__glubean_get_last_run_summary mcp__glubean__glubean_get_local_events
---

# Glubean

Use this skill in one of three modes:

1. **Docs mode**: the user has only the skill and is asking what Glubean is, how it works, how it compares to Postman, how to migrate, editor support, cloud features, or other product questions.
2. **Bootstrap mode**: the user has only the skill and wants to try Glubean, generate a demo, install tools, run a scratch test, or get to a first successful run.
3. **Project mode**: the user is already inside a Glubean project and wants to write, run, or fix tests.

## Route first

Before choosing a workflow, inspect the workspace:

- Check for `package.json`, `config/`, `tests/`, `explore/`, `.env`, `.env.secrets`, and `GLUBEAN.md`.
- Check whether `@glubean/sdk` is already present in dependencies or devDependencies.
- Check whether MCP tools are available.

Then route by intent plus environment:

- **Docs mode** if the user is asking for explanation or product guidance and there is no active project task.
- **Bootstrap mode** if there is no Glubean project yet and the user wants to start using Glubean now.
- **Project mode** if the repo already looks like a Glubean project, or the user explicitly wants test work in an existing project.

If `GLUBEAN.md` exists in the project root, read it first. It overrides default conventions.

## Hard rules

Always follow these unless project-specific instructions override them:

1. Secrets go in `.env.secrets`; public config goes in `.env`.
2. Use `configure()` for shared HTTP clients; do not write raw `fetch()` as the normal project pattern.
3. Use `{{KEY}}` for env and secret interpolation, bare strings for literals.
4. Put tags on every test.
5. Use builder mode when a test needs teardown or multi-step state passing.
6. Use kebab-case test IDs, unique across the project.
7. Prefer shared response types from `types/` over duplicated inline types.
8. Treat `test.each` and `test.pick` as parameter variation for the same endpoint, not a way to group unrelated endpoints together.

## Mode guides

### Docs mode

- Answer from the bundled docs. Do not rely on inline product summaries from this file.
- Start with [references/index.md](references/index.md), then read only the relevant docs under `references/docs/`.
- For common questions:
  - What is Glubean / core concepts: [references/docs/getting-started/concepts.mdx](references/docs/getting-started/concepts.mdx)
  - First test / getting started: [references/docs/getting-started/first-test.mdx](references/docs/getting-started/first-test.mdx)
  - Comparison / migration: [references/docs/extension/comparison.mdx](references/docs/extension/comparison.mdx), [references/docs/extension/migrate-from-postman.mdx](references/docs/extension/migrate-from-postman.mdx)
  - QA teams: [references/docs/extension/for-qa-teams.mdx](references/docs/extension/for-qa-teams.mdx)
  - VS Code extension: [references/docs/extension/editor-experience.mdx](references/docs/extension/editor-experience.mdx)
  - Cloud features: [references/docs/cloud/index.mdx](references/docs/cloud/index.mdx)

### Bootstrap mode

- Use this when the user has the skill only and wants to start trying Glubean.
- Read [references/patterns/bootstrap.md](references/patterns/bootstrap.md).
- The goal is to get the user to a first successful demo run, then guide them toward VS Code and a real project setup.
- Preferred sequence:
  1. Install what is missing.
  2. Configure MCP.
  3. Create and run a scratch demo.
  4. Explain the VS Code extension value.
  5. Suggest `glubean init` for the real project once the scratch demo works.

### Project mode

- Use this when working inside an existing Glubean project.
- Read [references/project-workflow.md](references/project-workflow.md) first.
- Then read [references/index.md](references/index.md) and only the patterns needed for the current task.
- Use MCP tools for run/fix loops whenever available. CLI is fallback only when MCP is unavailable.

If `$ARGUMENTS` is provided, treat it as the target endpoint, file, tag, or natural-language test request.
