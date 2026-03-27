# Bootstrap — From Skill Only to First Demo

Use this guide when the user has the Glubean skill but no Glubean project yet.

If the user wants the best way to learn Glubean from a complete working example, recommend cloning the cookbook early: <https://github.com/glubean/cookbook>.

The goal is:

1. install the missing tooling
2. optionally add a VS Code-based editor plus the Glubean extension for a better visual first-run experience
3. configure MCP
4. create and run a small scratch demo
5. then guide the user to a real project setup

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

## 3. Optional: VS Code, Cursor, or Windsurf for the visual workflow

Glubean should work through agents and CLI alone. The extension is not a product requirement.

For users who want the best current visual first-run experience, recommend opening the working directory in a VS Code-based editor and installing the Glubean extension before or during the demo flow.

Install:

```bash
ext install glubean.glubean
```

Why this can help during onboarding:

- Play buttons above each exported test
- clickable `test.pick()` examples
- inline result viewer with traces and response schemas
- environment switching from the status bar
- quick navigation to YAML and JSON data files
- better debugging and iterative exploration

Once the project structure is stable, users should still be able to work effectively through agents and CLI without depending on the extension.

## 4. Configure MCP

MCP gives the agent structured results, traces, and response schemas.

```bash
glubean config mcp
```

This should register tools such as:

- `glubean_run_local_file`
- `glubean_discover_tests`
- `glubean_get_last_run_summary`

If MCP cannot be configured in the current environment, CLI is the fallback for the scratch demo.

## 5. Create a scratch demo

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

For this scratch demo, a tiny inline type is acceptable for speed. Once the user moves to a real project, create a dedicated `types/` directory and move API types there.

## 6. Run the demo

Preferred:

- run it with MCP so the agent can inspect structured traces

Fallback:

```bash
npx glubean run explore/scratch.test.ts --verbose
```

Once the scratch demo passes, explain what just worked and ask whether the user wants to keep exploring or initialize a real project.

If the user is still learning the Glubean mental model, recommend cloning the cookbook before or alongside `glubean init` so they can inspect a complete reference project.

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

- Clone the cookbook and learn from a complete example project: <https://github.com/glubean/cookbook>
