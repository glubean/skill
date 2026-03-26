# Bootstrap — From Zero to First Test

This guide is for users who just installed the Glubean skill but have nothing else set up yet.

## Prerequisites

- Node.js 18+
- A `package.json` in the project (run `npm init -y` if needed)

## Step 1: VS Code (or Cursor/Windsurf) + Extension

Glubean works from any terminal (`npx glubean run`), but VS Code-based editors unlock the full experience.

**Strongly recommended.** Here's why:

### Why VS Code?

- **▶ Play buttons** — click to run any test, no CLI commands to remember
- **Pick examples** — `test.pick()` cases show as clickable CodeLens buttons, like Postman's Examples
- **📄 Open data** — one click to jump from test code to the YAML/JSON data file driving it
- **💡 Refactor** — AI-assisted refactoring: extract data, convert to pick, promote to tests/
- **Result Viewer** — structured output with traces, assertions, and response schemas inline
- **📌 Pin** — pin frequently-used tests to the Glubean sidebar for one-click access
- **Environments** — switch `.env` profiles from the status bar, hover to preview variables
- **Debugging** — set breakpoints in test code, inspect variables, step through HTTP calls

Without the extension, you can still write and run tests via CLI — you just lose the visual workflow.

**Extension supported in:** VS Code, Cursor, Windsurf — any editor that supports VS Code extensions.
**CLI works everywhere:** terminal, Claude Code, Codex, any environment with Node.js.

**Install the extension:**
```
ext install glubean.glubean
```

After install, `.test.ts` files will show Play buttons above each test export.

## Step 2: Choose your path

Ask the user:

> **Want to try it first, or set up a real project?**
>
> 1. **Scratch** — write a single test file against a public API (DummyJSON). No config, no auth, 30 seconds to first Play button.
> 2. **Init** — full project setup with config, .env, directory structure for your own API.
>
> *Want to see a complete example first?* Clone the [cookbook](https://github.com/glubean/cookbook) — it has config, data-driven tests, explore flows, and builder patterns you can browse and run.

## Path A: Scratch (try it)

Install the SDK and create a scratch file:

```bash
npm install -D @glubean/sdk @glubean/runner
```

Create `explore/scratch.test.ts`:

```typescript
import { test } from "@glubean/sdk";

export const health = test(
  { id: "dj-health", tags: ["smoke"] },
  async (ctx) => {
    const res = await ctx.http.get("https://dummyjson.com/test");
    ctx.expect(res).toHaveStatus(200);
  },
);

export const getProduct = test(
  { id: "dj-product", tags: ["smoke"] },
  async (ctx) => {
    const product = await ctx.http
      .get("https://dummyjson.com/products/1")
      .json<{ id: number; title: string }>();

    ctx.expect(product.id).toBe(1);
    ctx.expect(product.title).toBeDefined();
    ctx.log(`${product.title}`);
  },
);
```

The user should now see ▶ Play buttons above each `export const` in VS Code.
Click Play to run. Results appear in the Glubean panel.

**After scratch works**, ask: "Want to set up a real project with `npx glubean init`, or keep exploring?"

## Path B: Init (real project)

```bash
npx glubean init
```

This creates:
- `config/` — HTTP client configuration with `configure()`
- `.env` — public variables (base URLs, feature flags)
- `.env.secrets` — private credentials (gitignored)
- `explore/` — directory for interactive test development
- `tests/` — directory for CI regression tests
- `tsconfig.json` — if not present

After init, the user needs to:
1. Set their base URL in `.env`
2. Add credentials to `.env.secrets` (if the API requires auth)
3. Write their first test in `explore/`

## Step 3: MCP tools (optional, recommended)

MCP tools give the agent structured run results with response schemas and traces.

```bash
npx glubean config mcp
```

This registers `glubean_run_local_file`, `glubean_discover_tests`, etc.
Without MCP, tests can still be run via `npx glubean run <file> --verbose`.

## Step 4: Lens docs

```bash
npx glubean docs pull
```

Pulls pattern docs to `~/.glubean/docs/`. The agent reads these for SDK patterns, auth strategies, data-driven testing, etc.

## What the user should see after setup

In VS Code, opening a `.test.ts` file shows:
- **▶ Play** buttons above each test export
- **▶ Pick example** buttons for `test.pick()` tests
- **📄 Open data** links above data loader calls
- **💡** lightbulb for AI-assisted refactoring
- **📌 Pin** to add tests to the Glubean sidebar

The Play button runs the test and shows results in the Glubean output panel.
