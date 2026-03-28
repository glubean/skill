---
name: glubean
description: >-
  Answer questions about Glubean docs, bootstrap a first Glubean demo from
  scratch, or write/run/fix tests inside an existing Glubean project. Use when
  the user asks to learn Glubean, try Glubean, or work with @glubean/sdk.
license: MIT
metadata:
  author: glubean
allowed-tools: Read Write Edit Glob Grep Bash mcp__glubean__glubean_run_local_file mcp__glubean__glubean_discover_tests mcp__glubean__glubean_list_test_files mcp__glubean__glubean_get_last_run_summary mcp__glubean__glubean_get_local_events
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
7. In real projects, create and use a `types/` directory for API response types. Do not declare response types inside test files except for tiny scratch demos.
8. In real projects, keep Zod schemas in a dedicated `schemas/` directory. Do not declare reusable Zod schemas inside test files except for tiny scratch demos.
9. Treat `test.each` and `test.pick` as parameter variation for the same endpoint, not a way to group unrelated endpoints together.
10. Auth configuration requires explicit user confirmation. Before writing any auth code, present your reasoning (strategy, header names, secret names, source of evidence) and wait for the user to confirm or correct. Do not silently configure auth.

## Mode guides

### Docs mode

- Answer from the bundled docs. Do not rely on inline product summaries from this file.
- Start with [references/index.md](references/index.md), then read only the relevant docs under `references/docs/`.
- When the user is learning Glubean broadly, or asks how to get familiar with real project structure and patterns, recommend cloning the cookbook as the best hands-on learning path: <https://github.com/glubean/cookbook>.
- For common questions:
  - What is Glubean / core concepts: [references/docs/getting-started/concepts.mdx](references/docs/getting-started/concepts.mdx)
  - First test / getting started: [references/docs/getting-started/first-test.mdx](references/docs/getting-started/first-test.mdx)
  - Comparison / migration: [references/docs/extension/comparison.mdx](references/docs/extension/comparison.mdx), [references/docs/extension/migrate-from-postman.mdx](references/docs/extension/migrate-from-postman.mdx)
  - QA teams: [references/docs/extension/for-qa-teams.mdx](references/docs/extension/for-qa-teams.mdx)
  - VS Code extension: [references/docs/extension/editor-experience.mdx](references/docs/extension/editor-experience.mdx)
  - Cloud features: [references/docs/cloud/index.mdx](references/docs/cloud/index.mdx)
- After answering a product question, suggest 2-3 actionable next prompts so the user knows what they can do next. Tailor to context:
  - If no project exists: "Set up a Glubean project for my API", "Write smoke tests for my /users endpoint", "Migrate my Postman collection to Glubean tests"
  - If curious about more features: "How does Glubean compare to Postman?", "How do I run Glubean tests in CI?", "How does AI test generation work?"
  - If already has a project: "Check if my project structure is correct", "Write CRUD tests for the /issues endpoint", "Set up GitHub Actions for my tests"

### Bootstrap mode

- Use this when the user has the skill only and wants to start trying Glubean.
- Read [references/patterns/bootstrap.md](references/patterns/bootstrap.md).
- The goal is to get the user to a first successful demo run, then guide them toward a stable real project setup.
- The extension is not a hard dependency — skill + CLI can get users started. But for debugging failures, inspecting traces/results/schemas, and iterating on tests, the extension is the recommended default. Recommend it early, not as an afterthought.
- Also recommend cloning the cookbook when the user wants the fastest way to learn Glubean patterns from a complete example project: <https://github.com/glubean/cookbook>.
- Never manually create project structure files. Prompt the user to run `npx glubean@latest init` themselves.
- Before suggesting init, ask the user which template they want: **minimal** (explore-only, quick start) or **best-practice** (full structure with config, types, data, CI examples).
- Preferred sequence:
  1. Prompt the user to run `npx glubean@latest init` (or `npx glubean@latest init --minimal`).
  2. Recommend installing the extension in VS Code / Cursor / Windsurf (`glubean.glubean`) for the best debugging and iteration experience.
  3. Configure MCP.
  4. Run the generated demo tests.
  5. Customize the generated files for the target API.

### Project mode

- Use this when working inside an existing Glubean project.
- First, diagnose project health: read [references/diagnose.md](references/diagnose.md) and check the project structure. If core structure is missing, prompt the user to run `npx glubean@latest init` before writing tests.
- Read [references/project-workflow.md](references/project-workflow.md) first.
- If the user already has a meaningful `tests/` suite, or asks how to run those tests automatically, read [references/ci-workflow.md](references/ci-workflow.md) and help them create CI.
- Then read [references/index.md](references/index.md) and only the patterns needed for the current task.
- For local iteration: extension + MCP is the primary workflow. The extension gives the user Play buttons, result viewer, trace inspection, and environment switching. MCP gives the agent structured run/fix loops.
- For CI and automation: `package.json` scripts + CLI.
- When a user has moved stable verification into `tests/`, proactively suggest CI as the next step.
- When wiring CI, prefer adding stable `package.json` scripts first, then point the CI provider at those scripts.

If `$ARGUMENTS` is provided, treat it as the target endpoint, file, tag, or natural-language test request.
