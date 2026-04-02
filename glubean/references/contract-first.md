# Contract-First

Core logic:

- `product/` is intent.
- `contracts/` is the executable contract source of truth.
- `tests/` is the stable regression subset after behavior is implemented and proven.

Workflow:

1. Read `product/_index.md` first when it exists.
2. If the feature intent is missing or outdated, update `product/` before writing contracts.
3. Start with a resource-level plan when the request implies an API family, not a single endpoint.
4. Write or update contracts in `contracts/`.
5. Stop and ask whenever intent is ambiguous or contradictory. Escalation is mandatory here.
6. After contract review, implement and run until green. Fix implementation, not the confirmed contracts.
7. Promote a stable subset into `tests/` when it becomes regression coverage.

Rules:

- Do not write new contracts in `explore/` or `tests/`.
- Use `ctx.validate(zodSchema)` for schema contracts.
- Use `.step()` chains for workflow contracts.
- Read project context files and any user-specified context locations before making technical decisions.

Deep ref:

- Full writing guide: [patterns/contract-first.md](patterns/contract-first.md)
