# GraphQL Testing

> **Requires:** `npm install @glubean/graphql`

## Why this pattern

**Problem:** GraphQL is not just "HTTP with a different path". A GraphQL response can return HTTP 200 and still contain application errors in `errors[]`. REST-style smoke patterns often miss that and produce false positives.
**Alternative:** send raw POST requests with `ctx.http` and hand-roll JSON parsing — but that duplicates query handling, variable passing, and error checks.
**This pattern:** use `@glubean/graphql` so queries, mutations, variables, and `errors[]` handling are explicit and consistent.

## When to use this

- The API under test exposes a GraphQL endpoint
- The user asks for query or mutation tests
- The project already uses `@glubean/graphql`

For REST endpoints, use the normal HTTP patterns instead.

## Configure plugin mode (preferred for projects)

```typescript
import { configure, test } from "@glubean/sdk";
import { graphql } from "@glubean/graphql";

const { gql } = configure({
  plugins: {
    gql: graphql({
      endpoint: "{{GRAPHQL_URL}}",
      headers: { Authorization: "Bearer {{API_TOKEN}}" },
      throwOnGraphQLErrors: true,
    }),
  },
});

export const getUser = test("get-user", async (ctx) => {
  const { data } = await gql.query<{ user: { id: string; name: string } }>(
    `query GetUser($id: ID!) { user(id: $id) { id name } }`,
    { variables: { id: "1" } },
  );

  ctx.expect(data?.user.name).toBe("Alice");
});
```

Use plugin mode when the project will have multiple GraphQL tests. It keeps the endpoint and headers in shared config.

## Standalone mode (good for quick exploration)

```typescript
import { test } from "@glubean/sdk";
import { createGraphQLClient } from "@glubean/graphql";

export const health = test("graphql-health", async (ctx) => {
  const gql = createGraphQLClient(ctx.http, {
    endpoint: ctx.vars.require("GRAPHQL_URL"),
    headers: { Authorization: `Bearer ${ctx.secrets.require("API_TOKEN")}` },
  });

  const { data } = await gql.query<{ health: string }>(`{ health }`);
  ctx.expect(data?.health).toBe("ok");
});
```

Use standalone mode for one-off exploratory tests or scratch demos.

## Queries, mutations, and variables

Use `query()` for reads and `mutate()` for writes. Always pass variables instead of string-concatenating values into the document.

```typescript
const GET_USER = `
  query GetUser($id: ID!) {
    user(id: $id) { id name email }
  }
`;

const UPDATE_USER = `
  mutation UpdateUser($id: ID!, $name: String!) {
    updateUser(id: $id, input: { name: $name }) { id name }
  }
`;

const { data: userData } = await gql.query<{ user: { id: string; name: string } }>(
  GET_USER,
  { variables: { id: "1" } },
);

const { data: updateData } = await gql.mutate<{ updateUser: { id: string; name: string } }>(
  UPDATE_USER,
  { variables: { id: "1", name: "Alice" } },
);
```

For larger operations, prefer `gql` tagged templates or `fromGql()` from the plugin docs.

## Error handling rule

GraphQL success is not just HTTP success.

### Default recommendation for happy-path regression tests

Set `throwOnGraphQLErrors: true` so a non-empty `errors[]` fails fast. This is the safest default for `tests/`.

### When you are intentionally testing GraphQL errors

Set `throwOnGraphQLErrors: false` and assert on `errors[]` directly:

```typescript
const { gql } = configure({
  plugins: {
    gql: graphql({
      endpoint: "{{GRAPHQL_URL}}",
      throwOnGraphQLErrors: false,
    }),
  },
});

export const invalidUser = test("invalid-user-query", async (ctx) => {
  const result = await gql.query<{ user: null }>(
    `query GetUser($id: ID!) { user(id: $id) { id } }`,
    { variables: { id: "missing" } },
  );

  ctx.expect(result.errors?.length ?? 0).toBeGreaterThan(0);
  ctx.expect(result.errors?.[0]?.message).toContain("not found");
});
```

## Assertion guidance

- Assert business fields in `data`, not the entire response object
- Do not treat HTTP 200 as sufficient proof of success
- For regression tests, assert that `errors[]` is absent or fail fast with `throwOnGraphQLErrors: true`
- Use the same depth rules as REST once you are inside `data`. See [assertions.md](assertions.md)

## Common mistakes

- Using raw `ctx.http.post()` for every GraphQL test instead of the plugin
- Interpreting HTTP 200 as success without checking `errors[]`
- Inlining variables into the query string instead of using the `variables` option
- Keeping large query documents inline when they should live in `.gql` files
