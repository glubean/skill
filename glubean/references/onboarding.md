# Onboarding

Goal:

1. Choose the right starting path.
2. Install the extension.
3. Configure MCP.
4. Get the user into a real Glubean project.

Preferred order:

1. Ask whether the user wants to learn from the cookbook or start in their own repo.
2. Recommend the extension in VS Code / Cursor / Windsurf: `glubean.glubean`.
3. Configure MCP with `npx glubean@latest config mcp` or `npx add-mcp "npx -y @glubean/mcp@latest"`.
4. If the user wants their own repo, have them run `npx glubean@latest init` themselves. The interactive wizard offers three paths: try (cookbook), test an existing API, or contract-first.
5. If the user is migrating from existing assets (Postman, Apifox, OpenAPI, `.http`, cURL, legacy tests), run init first, then follow [patterns/migration.md](patterns/migration.md).
6. Once a repo exists, switch to [project-mode.md](project-mode.md).

Rules:

- Do not hand-create scaffold files such as `package.json`, `.env`, `.env.secrets`, `.gitignore`, or `config/`.
- Treat scratch mode as an extension-only quick demo path. Mention it only if the user explicitly asks for the fastest zero-config editor experience.
- Recommend the cookbook early when the user wants a complete example project: <https://github.com/glubean/cookbook>.

Deep refs:

- Setup details: [patterns/bootstrap.md](patterns/bootstrap.md)
- MCP details: [mcp.md](mcp.md)
- Extension quick start: [docs/extension/quick-start.mdx](docs/extension/quick-start.mdx)
