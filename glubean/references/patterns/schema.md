# Schema Validation (Zod)

Validate API response structure against a Zod schema.

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
