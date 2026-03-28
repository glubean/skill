# Bootstrap — From Skill Only to First Demo

Use this guide when the user has the Glubean skill but no Glubean project yet.

If the user wants the best way to learn Glubean from a complete working example, recommend cloning the cookbook early: <https://github.com/glubean/cookbook>.

The goal is:

1. initialize a project with the CLI
2. optionally add a VS Code-based editor plus the Glubean extension for a better visual first-run experience
3. configure MCP
4. run the generated demo, then customize for the target API

## CLI-first rule

Never manually create project structure files (`package.json`, `.env`, `.env.secrets`, `.gitignore`, `config/`, etc.). Always prompt the user to run the CLI themselves. The CLI generates correct defaults, dependencies, and scaffolding that manual creation would miss.

## 1. Initialize the project

Prerequisites:

- Node.js 20+
- a writable working directory

Before suggesting init, ask the user which template they want:

> Do you want the **minimal** template (bare essentials — explore-only, quick start) or the **best-practice** template (full project structure with config, types, data directories, CI examples)?

Then prompt the user to run:

```bash
npx glubean@latest init            # best-practice template
npx glubean@latest init --minimal  # quick-start template
```

The CLI handles everything: `package.json`, dependencies, `.env`, `.env.secrets`, `.gitignore`, `config/`, `explore/`, `tests/`, `types/`, and runs `npm install` automatically.

Do not run `npx glubean@latest init` on behalf of the user — it is an interactive wizard that requires their input.

## 2. Install the extension (recommended)

The extension is not a hard dependency — skill + CLI can get users started. But for debugging failures, inspecting traces and response schemas, and iterating on tests, the extension is the recommended default. Recommend it early, not as an afterthought.

Open the project in VS Code, Cursor, or Windsurf and install:

```bash
ext install glubean.glubean
```

What the extension gives you:

- Play buttons above each exported test
- inline result viewer with traces and response schemas
- environment switching from the status bar
- clickable `test.pick()` examples
- quick navigation to YAML and JSON data files

Without the extension, users can still write and run tests through agents and CLI. But once they are debugging failures or inspecting responses, the extension is significantly faster.

## 3. Configure MCP

MCP gives the agent structured results, traces, and response schemas — this is what makes the agent write/run/fix loop effective. Without MCP, structured failure data is discarded and the agent can only read plain text CLI output.

For Claude Code, Codex, Cursor, and Windsurf, the CLI auto-configures it:

```bash
npx glubean@latest config mcp
```

For other MCP-compatible clients, or if `glubean config mcp` is unavailable, add this to the client's MCP config:

```json
{
  "mcpServers": {
    "glubean": {
      "command": "npx",
      "args": ["-y", "@glubean/mcp@latest"]
    }
  }
}
```

See [../mcp.md](../mcp.md) for config locations per client, Codex TOML format, and the full tool reference.

If MCP cannot be configured at all, CLI is the fallback for the scratch demo.

## 4. Run the generated demo

`glubean init` creates demo tests in `explore/` and `tests/`. Run them immediately to verify the setup works.

Preferred:

- run with MCP so the agent can inspect structured traces

Fallback:

```bash
npx glubean@latest run explore/ --verbose
```

Once the demo passes, explain what just worked.

## 5. Customize for the target API

After the demo runs successfully:

1. Set `BASE_URL` and other public vars in `.env`
2. Put credentials in `.env.secrets`
3. Write the first real test in `explore/`

Do not manually recreate files that `glubean init` already generated. Edit the generated files to match the target API instead.

If the user is still learning the Glubean mental model, recommend cloning the cookbook so they can inspect a complete reference project.

## Optional next steps

- Clone the cookbook and learn from a complete example project: <https://github.com/glubean/cookbook>
