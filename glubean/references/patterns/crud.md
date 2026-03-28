# CRUD with Setup/Teardown

## When to use builder mode

Use builder mode (`.setup()` / `.step()` / `.teardown()`) when your test:
- Creates resources that must be cleaned up
- Has multiple sequential steps that depend on each other

For simple read-only tests, quick mode (callback) is fine.

## Quick mode has NO teardown

```typescript
// ❌ WRONG: teardown does not exist on TestContext — crashes at runtime
export const createThing = test("create", async ({ teardown }) => {
  const res = await api.post("things", { json: { name: "test" } }).json<{ id: string }>();
  teardown(async () => { await api.delete(`things/${res.id}`); }); // undefined!
});

// ✅ RIGHT: use builder mode for cleanup
```

## Full CRUD example (builder mode)

Multi-step test: create a resource, verify, update, then always clean up.

```typescript
// tests/api/projects.test.ts
import { test } from "@glubean/sdk";
import { api } from "../../config/api.ts";

export const projectsCrud = test("projects-crud")
  .meta({ name: "Projects CRUD lifecycle", tags: ["api", "projects"] })
  .setup(async ({ log }) => {
    log("Creating test project");
    const project = await api
      .post("projects", { json: { name: "test-project", teamId: "my-team" } })
      .json<{ id: string }>();
    return { projectId: project.id };
  })
  .step("read", async ({ expect }, state) => {
    const project = await api.get(`projects/${state.projectId}`).json<{ name: string }>();
    expect(project.name).toBe("test-project");
    return state;
  })
  .step("update", async ({ expect }, state) => {
    const updated = await api
      .put(`projects/${state.projectId}`, { json: { name: "renamed" } })
      .json<{ name: string }>();
    expect(updated.name).toBe("renamed");
    return state;
  })
  .teardown(async ({ log }, state) => {
    if (state?.projectId) {
      await api.delete(`projects/${state.projectId}`);
      log(`Cleaned up project ${state.projectId}`);
    }
  });
```

## Key points

- **`.teardown()` always runs**, even when a step fails — use it for cleanup
- Each `.step()` receives state from the previous step and returns new state
- Steps appear as separate entries in reports with individual durations

## Explore-style CRUD (individual exports)

Use this pattern in `explore/` where each operation should be independently runnable.
Instead of one builder that chains the full lifecycle, export separate tests so the user can run, iterate, and inspect each operation on its own.

Inline types are acceptable in `explore/` files.

```typescript
// explore/issues.test.ts
import { test } from "@glubean/sdk";
import { api } from "../config/api.ts";

export const createIssue = test("create-issue")
  .meta({ name: "Create issue", tags: ["explore", "issues"] })
  .setup(async ({ log }) => {
    const issue = await api
      .post("issues", { json: { title: "test issue", body: "created by explore" } })
      .json<{ id: number; title: string }>();
    log(`Created issue #${issue.id}`);
    return { issueId: issue.id };
  })
  .step("verify", async ({ expect }, state) => {
    const issue = await api.get(`issues/${state.issueId}`).json<{ title: string }>();
    expect(issue.title).toBe("test issue");
    return state;
  })
  .teardown(async ({ log }, state) => {
    if (state?.issueId) {
      await api.patch(`issues/${state.issueId}`, { json: { state: "closed" } });
      log(`Closed issue #${state.issueId}`);
    }
  });

export const getIssue = test(
  { id: "get-issue", name: "Read a known issue", tags: ["explore", "issues"] },
  async ({ expect }) => {
    const issue = await api.get("issues/1").json<{ id: number; title: string }>();
    expect(issue.id).toBe(1);
    expect(issue.title).toBeDefined();
  },
);

export const updateIssue = test("update-issue")
  .meta({ name: "Update issue", tags: ["explore", "issues"] })
  .setup(async () => {
    const issue = await api
      .post("issues", { json: { title: "before update" } })
      .json<{ id: number }>();
    return { issueId: issue.id };
  })
  .step("update", async ({ expect }, state) => {
    const updated = await api
      .patch(`issues/${state.issueId}`, { json: { title: "after update" } })
      .json<{ title: string }>();
    expect(updated.title).toBe("after update");
    return state;
  })
  .teardown(async ({ log }, state) => {
    if (state?.issueId) {
      await api.patch(`issues/${state.issueId}`, { json: { state: "closed" } });
      log(`Closed issue #${state.issueId}`);
    }
  });

export const deleteIssue = test("delete-issue")
  .meta({ name: "Delete/close issue", tags: ["explore", "issues"] })
  .setup(async () => {
    const issue = await api
      .post("issues", { json: { title: "to be deleted" } })
      .json<{ id: number }>();
    return { issueId: issue.id };
  })
  .step("delete", async ({ expect }, state) => {
    const closed = await api
      .patch(`issues/${state.issueId}`, { json: { state: "closed" } })
      .json<{ state: string }>();
    expect(closed.state).toBe("closed");
    return state;
  })
  .teardown(async ({ log }, state) => {
    log(`Issue #${state?.issueId} already closed by delete step`);
  });
```

### When to use which pattern

| Target directory | Pattern | Why |
|---|---|---|
| `explore/` | Individual exports (above) | Each operation is independently runnable for interactive exploration |
| `tests/` | Builder lifecycle (full CRUD example above) | Single test covers the full regression path with guaranteed cleanup |
