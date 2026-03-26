# Bootstrap — From Skill Only to First Demo

Use this guide when the user has the Glubean skill but no Glubean project yet.

The goal is:

1. install the missing tooling
2. configure MCP
3. create and run a small scratch demo
4. then guide the user to VS Code and a real project setup

## 1. Prepare the workspace

Prerequisites:

- Node.js 18+
- a writable working directory

If there is no `package.json` yet, initialize one first:

```bash
npm init -y
```

## 2. Install the tools needed for a first run

Install the CLI and local runtime:

```bash
npm install -g @glubean/cli
npm install -D @glubean/sdk @glubean/runner
```

The global CLI is for setup commands such as `glubean init` and `glubean config mcp`.
The local packages are enough to create and run a scratch test immediately.

## 3. Configure MCP

MCP gives the agent structured results, traces, and response schemas.

```bash
glubean config mcp
```

This should register tools such as:

- `glubean_run_local_file`
- `glubean_discover_tests`
- `glubean_get_last_run_summary`

If MCP cannot be configured in the current environment, CLI is the fallback for the scratch demo.

## 4. Create a scratch demo

Create `explore/scratch.test.ts`:

```typescript
import { test } from "@glubean/sdk";

export const health = test(
  { id: "dummyjson-health", tags: ["smoke"] },
  async (ctx) => {
    const res = await ctx.http.get("https://dummyjson.com/test");
    ctx.expect(res).toHaveStatus(200);
  },
);

export const getProduct = test(
  { id: "dummyjson-product", tags: ["smoke"] },
  async (ctx) => {
    const product = await ctx.http
      .get("https://dummyjson.com/products/1")
      .json<{ id: number; title: string }>();

    ctx.expect(product.id).toBe(1);
    ctx.expect(product.title).toBeDefined();
  },
);
```

## 5. Run the demo

Preferred:

- run it with MCP so the agent can inspect structured traces

Fallback:

```bash
npx glubean run explore/scratch.test.ts --verbose
```

Once the scratch demo passes, explain what just worked and ask whether the user wants to keep exploring or initialize a real project.

## 6. Guide the user to VS Code-based editors

After the first run succeeds, strongly recommend the extension if the user has access to VS Code, Cursor, or Windsurf.

Install:

```bash
ext install glubean.glubean
```

Why it matters:

- Play buttons above each exported test
- clickable `test.pick()` examples
- inline result viewer with traces and response schemas
- environment switching from the status bar
- quick navigation to YAML and JSON data files
- better debugging and iterative exploration

Tests still work fine from CLI without the extension, but the editor experience is much better with it.

## 7. Move from scratch to a real project

When the user is ready:

```bash
glubean init
```

This creates the standard project structure:

- `config/`
- `explore/`
- `tests/`
- `.env`
- `.env.secrets`

After init, guide the user to:

1. set `BASE_URL` and other public vars in `.env`
2. put credentials in `.env.secrets`
3. write the first real test in `explore/`

## Optional next steps

- Pull docs for local agent use: `glubean docs pull`
- Browse the cookbook for examples: <https://github.com/glubean/cookbook>
