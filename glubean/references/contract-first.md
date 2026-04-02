# Contract-First

Core logic:

- `product/` is intent.
- `contracts/` is the executable contract source of truth.
- `tests/` is the stable regression subset after behavior is implemented and proven.

Workflow:

1. If the user explicitly points to an external intent source such as an issue or doc URL, sync it into `product/` before writing contracts. Include the source link and sync time. If the source is inaccessible, ask the user to paste the content.
2. Read `product/_index.md` first when it exists.
3. If the feature intent is missing or outdated, update `product/` before writing contracts.
4. Start with a resource-level plan when the request implies an API family, not a single endpoint.
5. Write or update contracts in `contracts/`.
6. Stop and ask whenever intent is ambiguous or contradictory. Escalation is mandatory here.
7. After contract review, implement and run until green. Fix implementation, not the confirmed contracts.
8. Promote a stable subset into `tests/` when it becomes regression coverage.

Rules:

- Do not write new contracts in `explore/` or `tests/`.
- Use `ctx.validate(zodSchema)` for schema contracts.
- Use `.step()` chains for workflow contracts.
- Read project context files and any user-specified context locations before making technical decisions.

Deep ref:

- Full writing guide: [patterns/contract-first.md](patterns/contract-first.md)
