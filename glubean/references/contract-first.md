# Contract-First

Core logic:

- `contracts/` is the executable contract source of truth.
- `schemas/` holds reusable Zod schemas for response validation.
- `tests/` is for cases that `contract.http()` can't express (browser, polling, complex state).

Workflow:

1. If the user explicitly points to an external intent source such as an issue or doc URL, read it before writing contracts.
2. Start with a resource-level plan when the request implies an API family, not a single endpoint.
3. Write or update contracts in `contracts/` using `contract.http()` for endpoint specs.
4. Use `contract.flow()` for cross-endpoint lifecycle verification.
5. Stop and ask whenever intent is ambiguous or contradictory. Escalation is mandatory here.
6. After contract review, implement and run until green. Fix implementation, not the confirmed contracts.
7. `contract.http()` produces `Test[]` directly — no need to "promote" to `tests/`.

Rules:

- Do not write contracts in `explore/` or `tests/`.
- Use `contract.http()` with `cases` for structured API spec. Each case must have a `description`.
- Use `contract.flow()` for stateful endpoint chains (upload → read → delete).
- Use `test()` only for scenarios contract can't express (browser, polling, complex state machines).
- Keep Zod schemas in `schemas/`. Use `expect.schema` for response validation, not scattered assertions.
- Read project context files and any user-specified context locations before making technical decisions.

Deep ref:

- Full writing guide: [patterns/contract-first.md](patterns/contract-first.md)
