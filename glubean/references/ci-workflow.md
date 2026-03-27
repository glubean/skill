# CI Workflow

Use this guide when the user already has stable tests in `tests/` and wants the agent to wire them into CI.

## When to suggest CI

Suggest CI when one or more of these are true:

- the repo now has a meaningful regression suite under `tests/`
- the user asks for pull request checks, branch protection, or automatic runs
- the suite is no longer just exploration in `explore/`
- the user wants JUnit output, machine-readable artifacts, or Cloud upload from automation

## Primary references

Read these before making CI changes:

- [docs/getting-started/ci.mdx](docs/getting-started/ci.mdx)
- [docs/cli/reference.mdx](docs/cli/reference.mdx)
- [docs/cli/recipes.mdx](docs/cli/recipes.mdx)
- [docs/getting-started/upload-to-cloud.mdx](docs/getting-started/upload-to-cloud.mdx) if the user also wants Cloud results

## Default CI command

Prefer this shape:

1. put stable Glubean commands in `package.json` scripts
2. make CI call those scripts

Example:

```json
{
  "scripts": {
    "test:api": "glubean run tests/",
    "test:api:ci": "glubean run tests/ --ci --result-json .glubean/last-run.json --reporter junit:test-results.xml",
    "test:api:upload": "glubean run tests/ --ci --upload"
  }
}
```

Then the underlying CI command becomes:

```bash
npm run test:api:ci
```

Why this shape is preferred:

- the canonical command lives in one place
- local runs and CI runs stay aligned
- workflow files stay short and easier to review
- `tests/` stays the CI target for committed regression coverage
- `.glubean/last-run.json` and `junit:test-results.xml` stay stable across environments

## GitHub Actions

If the user wants GitHub Actions, prefer a workflow that calls the script:

```yaml
name: test-api
on: [push, pull_request]

jobs:
  glubean:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - run: npm ci
      - run: npm run test:api:ci
```

If the project already has a CI style, preserve the existing conventions instead of forcing this exact workflow.

## Faster path when initializing

If the user is still at project setup time and wants CI immediately, check whether `glubean init --hooks --github-actions` fits their workflow:

```bash
glubean init --hooks --github-actions
```

Use this only when creating or re-initializing the project structure makes sense. Do not overwrite a hand-maintained CI setup without good reason.

## Cloud upload in CI

If the user wants shared run history in Glubean Cloud, extend the CI command with upload:

```bash
npm run test:api:upload
```

Required CI secrets and variables:

- `GLUBEAN_TOKEN`
- `GLUBEAN_PROJECT_ID`

Store them in the CI provider's secret store, not in the repo.

## Metadata and validation

If the project uses metadata sync as a gate, also consider:

```bash
glubean validate-metadata
```

Use it when metadata drift matters to the team's workflow. Do not add it blindly if the project does not use metadata yet.

## Agent behavior

When creating CI for the user:

1. Reuse the repo's existing CI conventions if they already exist.
2. Add or update `package.json` scripts before editing the CI workflow file.
3. Keep CI focused on `tests/`, not `explore/`.
4. Prefer stable output locations for result JSON and JUnit XML.
5. Ask before adding Cloud upload if credentials are not already configured.
6. After creating CI, explain the script names and the artifacts they will produce.
