# Project Mode

Shared setup:

1. Run [diagnose.md](diagnose.md) only when: first time seeing this project, something fails unexpectedly, or the user explicitly asks. The route-first checks in SKILL.md are enough for normal visits.
2. If `@glubean/sdk` is missing from dependencies, stop and have the user run `npx glubean@latest init`. Other missing pieces (directories, env files) are not blocking — note them and continue.
3. Read `product/` when it exists and business intent matters, and always honor `GLUBEAN.md`.

Then route by intent — is the API already callable?

### Test-after (API exists)

Write, run, fix, and improve tests against an existing API.

1. Read [test-after-workflow.md](test-after-workflow.md) for the step-by-step writing workflow.
2. If the ask is broad coverage work, read [patterns/test-planning.md](patterns/test-planning.md) before writing code.
3. If the user is migrating from Postman, Apifox, OpenAPI, `.http`, cURL, or another test codebase, read [patterns/migration.md](patterns/migration.md) before generating files.
4. Use extension + MCP for local run/fix loops.
5. Move stable coverage into `tests/`, then suggest CI.

### Contract-first (API not yet implemented)

Define behavior as executable contracts before the API exists.

1. Read [contract-first.md](contract-first.md) for the entry workflow, then [patterns/contract-first.md](patterns/contract-first.md) for the full writing guide.
2. Write contracts in `contracts/`, not in `explore/` or `tests/`.
3. After implementation, promote stable contracts into `tests/`.
4. If the user asks about coverage status, or `contracts/` has 5+ files, suggest a projection report. Read [patterns/projection.md](patterns/projection.md).

Rules:

- Do not jump straight into code when the user really needs a gap report or test plan first.
- If the user shifts intent mid-task (test-after ↔ contract-first), re-route here.
- Prefer stable `package.json` scripts before wiring CI providers.
- When stable coverage lives in `tests/`, point the user to CI next.

Deep refs:

- Promotion: [patterns/promotion.md](patterns/promotion.md)
- CI: [ci-workflow.md](ci-workflow.md)
- MCP: [mcp.md](mcp.md)
