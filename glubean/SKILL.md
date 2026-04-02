---
name: glubean
description: >-
  Answer questions about Glubean docs, help users onboard into a real Glubean
  setup, or write/run/fix tests inside an existing Glubean project. Use when
  the user asks to learn Glubean, set it up, or work with @glubean/sdk.
license: MIT
metadata:
  author: glubean
allowed-tools: Read Write Edit Glob Grep Bash mcp__glubean__glubean_run_local_file mcp__glubean__glubean_discover_tests mcp__glubean__glubean_list_test_files mcp__glubean__glubean_get_last_run_summary mcp__glubean__glubean_get_local_events mcp__glubean__glubean_get_metadata
---

# Glubean

Use this skill as a Glubean best-practice guide. Default to the real project workflow. Scratch mode is an extension quick demo path, not the normal agent path.

## Modes

1. **Docs**: product questions, concepts, comparison, migration, editor support, or cloud features.
2. **Onboarding**: no Glubean project yet; the user needs extension, MCP, cookbook, or project init guidance.
3. **Project**: the user is already in a Glubean project, or clearly wants to do real project test work.

## Route first

Before choosing a mode:

- Check for `package.json`, `config/`, `product/`, `contracts/`, `tests/`, `explore/`, `.env`, `.env.secrets`, and `GLUBEAN.md`.
- Check whether `@glubean/sdk` is already present in dependencies or devDependencies.
- Check whether MCP tools are available.
- If `GLUBEAN.md` exists, read it first as the project's context file.
- Users should keep key context there, including pointers to relevant code, docs, specs, and sibling workspaces.
- If the user explicitly provides additional context locations, read those too before guessing from the API alone.

Then route by intent plus environment:

- **Docs**: explanation only, with no active project task. Read [references/docs-mode.md](references/docs-mode.md).
- **Onboarding**: no Glubean project yet, and the user wants to get set up properly. Read [references/onboarding.md](references/onboarding.md).
- **Project**: the repo already looks like a Glubean project, or the user wants real test work in one. Read [references/project-mode.md](references/project-mode.md).

## Intent examples

- Docs
  - "What is Glubean?"
  - "How does Glubean compare to Postman?"
  - "How do I run tests in CI?"
- Onboarding
  - "Set up Glubean for my project"
  - "I want to try Glubean"
  - "Configure MCP for Cursor"
- Project — test-after (API already exists)
  - "Write smoke tests for /users"
  - "Improve my test coverage"
  - "Fix this failing test"
  - "Add auth boundary tests"
- Project — contract-first (API not yet implemented)
  - "I need a users API with CRUD"
  - "Design the billing endpoint before I implement it"
  - "Write tests first, then I'll build the API"

## Global rules

Apply these unless project-specific instructions override them:

1. Secrets go in `.env.secrets`; public config goes in `.env`. For multi-environment setup, read [references/patterns/multi-env.md](references/patterns/multi-env.md).
2. Use `configure()` to create shared HTTP clients, then use the exported client (e.g. `api`) in tests — not `ctx.http`. `ctx.http` is only for scratch demos.
3. Use `{{KEY}}` for env and secret interpolation, bare strings for literals.
4. Put tags on every test.
5. Use builder mode when a test needs teardown or multi-step state passing.
6. Use kebab-case test IDs, unique across the project.
7. In real projects, keep reusable response types in `types/`. Inline them only for tiny throwaway examples the user explicitly asked for.
8. Do not use `.json<any>()`. If response shape is still unknown, start with `.json<unknown>()`. Use `Record<string, unknown>` only when you already know the top-level value is an object. Then narrow to a real type or Zod as soon as fields are known.
9. In real projects, keep reusable Zod schemas in `schemas/`. Inline them only for tiny throwaway examples the user explicitly asked for.
10. Use `test.each` and `test.pick` only when every case exercises the same endpoint or the same operation pattern. If endpoints are unrelated, write separate exported tests.
11. Auth configuration requires explicit user confirmation. Before writing any auth code, present your reasoning (strategy, header names, secret names, source of evidence) and wait for the user to confirm or correct. Do not silently configure auth.
12. If core project structure is missing, do not hand-create the scaffold. Prompt the user to run `npx glubean@latest init`.
13. When the user confirms a project-level decision (auth strategy, context location, naming convention, business rule), suggest adding it to `GLUBEAN.md` so future sessions pick it up.

For detailed navigation, start with [references/index.md](references/index.md).

If `$ARGUMENTS` is provided, treat it as the target endpoint, file, tag, or natural-language test request.
