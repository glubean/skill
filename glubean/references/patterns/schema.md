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
