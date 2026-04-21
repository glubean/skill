# Schema Validation (Zod)

Validate API response structure against a Zod schema.

## Why this pattern

**Problem:** field-by-field assertions (`expect(res.name).toBeDefined()`) only check the fields you remembered to write — new fields, removed fields, and type changes slip through silently.
**Alternative:** use `.toEqual()` with a full expected object — but this is brittle (breaks on any new field the API adds) and doesn't validate types or nested structure.
**This pattern:** a Zod schema validates the entire response shape in one call. It catches unexpected field removal, type mismatches, and structural drift. Schemas live in `schemas/` and are reusable across tests — one schema update fixes all tests that use it.

```typescript
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";
import { ProjectSchema } from "../../schemas/project.ts";

export const projectSchema = test(
  { id: "project-schema", name: "Project response matches schema", tags: ["api", "schema"] },
  async ({ validate }) => {
    const project = await api.get("projects").json();
    validate(project, ProjectSchema.array(), "Project list");
  },
);
```

```typescript
// schemas/project.ts
import { z } from "zod";

export const ProjectSchema = z.object({
  id: z.string(),
  name: z.string(),
  createdAt: z.string().datetime(),
  team: z.object({
    id: z.string(),
    name: z.string(),
  }),
});
```

## Key points

- `ctx.validate(data, schema, label?)` — validates and reports mismatches as assertion failures
- Use Zod v4 (`import { z } from "zod"`)
- Keep reusable schemas in `schemas/*.ts`, not in test files
- Third argument `label` appears in failure messages for clarity

## Inline variant — `ctx.http.*({ schema })`

When you want validation bound to a specific HTTP call (so tools can attribute failures to that request), pass `schema:` directly in the ky options. Unlike `ctx.validate`, this runs **pre-request** for request bodies/headers/query and **post-response** for the response body and headers — in a single declaration.

```typescript
import { z } from "zod";
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";
import { ProjectSchema, CreateProjectBody } from "../../schemas/project.ts";

export const createProjectWithSchema = test(
  { id: "create-project-schema" },
  async (ctx) => {
    await api.post("projects", {
      json: { name: "My Project", description: "Test" },
      headers: { "X-Tenant-Id": "t1" },
      schema: {
        request: CreateProjectBody,
        response: ProjectSchema,
        requestHeaders: z.object({ "X-Tenant-Id": z.string() }),
        responseHeaders: z.object({ "content-type": z.string() }),
      },
    }).json();
  },
);
```

Schema keys: `request`, `response`, `query`, `requestHeaders`, `responseHeaders`. Each accepts a bare schema or `{ schema, severity: "error" | "warn" | "fatal" }`. Headers are normalized to `Record<string, string>` before validation.

When to use which:

- `ctx.validate()` — when you already have the data in hand (e.g. after a custom fetch, or validating a computed value).
- `ctx.http.*({ schema })` — when validation naturally belongs to the request/response pair; avoids a separate `.json()` + `validate` round.
- `contract.http.with()` — when you want the entire endpoint spec (every case, every expected outcome) in one file. See [contract-first.md](contract-first.md).
