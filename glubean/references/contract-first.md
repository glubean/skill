# Contract-First

Core logic:

- `contracts/` is the executable contract source of truth.
- `schemas/` holds reusable Zod schemas for response validation.
- `tests/` is for cases that `contract.http()` can't express (browser, polling, complex state).

Fast entry: if the user is clearly asking to define the API before implementation, this is the first project-mode file to read after [SKILL.md](../SKILL.md). Do not let simple-mode defaults delay the contract-first route.

Workflow:

1. If the user explicitly points to an external intent source such as an issue or doc URL, read it before writing contracts.
2. Start with a resource-level plan when the request implies an API family, not a single endpoint.
3. **Pass the intent gate** — before writing any contract code, state what you understood (endpoints, auth, response shape, status codes, request body, business rules) and mark anything unclear with ❓. If ANY item is ❓, stop and ask the user. **Do not guess.** See [patterns/contract-first.md#intent-gate--ask-before-you-write](patterns/contract-first.md).
4. Write or update contracts in `contracts/` using `contract.http()` for endpoint specs.
5. Use `contract.flow()` for cross-endpoint lifecycle verification.
6. After contract review, implement and run until green. Fix implementation, not the confirmed contracts.
7. `contract.http()` produces `Test[]` directly — no need to "promote" to `tests/`.

Rules:

- Do not write contracts in `explore/` or `tests/`.
- Use `contract.http()` with `cases` for structured API spec. Each case must have a `description`.
- Use `contract.flow()` for stateful endpoint chains (upload → read → delete).
- Use `test()` only for scenarios contract can't express (browser, polling, complex state machines).
- Keep Zod schemas in `schemas/`. Use `expect.schema` for response validation, not scattered assertions.
- Put project-level biz logic in `GLUBEAN.md` when needed (roles, state machines, domain rules). Do not hand-write endpoint/status/schema/case inventories in prose; keep those in `contracts/`.
- Read project context files and any user-specified context locations before making technical decisions.

Deep ref:

- Full writing guide: [patterns/contract-first.md](patterns/contract-first.md)
