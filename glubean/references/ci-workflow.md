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

1. put run config in `ci-config/*.yaml` files (one per environment)
2. put `package.json` scripts that point at those configs
3. make CI call those scripts

### Config files

`glubean init` generates these by default. In an already initialized project, add them if they do not exist. If core project structure is still missing, go back to `glubean init` first instead of hand-creating around a half-initialized repo:

**ci-config/default.yaml** — local development:

```yaml
# Default run config — used by: npm test
run:
  testDir: ./tests
  exploreDir: ./explore
  verbose: false
  pretty: true

redaction:
  replacementFormat: simple
```

**ci-config/ci.yaml** — CI pipelines:

```yaml
# CI run config — used by: npm run test:ci
# Optimized for CI pipelines: fail fast, structured output, no pretty-print
run:
  testDir: ./tests
  failFast: true
  pretty: false
  # Emit full HTTP trace in results (useful for debugging CI failures)
  emitFullTrace: false
  # Stop after N failures (uncomment to enable)
  # failAfter: 5

redaction:
  replacementFormat: simple
```

**ci-config/staging.yaml** — staging environment:

```yaml
# Staging run config — used by: npm run test:staging
run:
  testDir: ./tests
  envFile: .env.staging
  verbose: false
  pretty: true

redaction:
  replacementFormat: simple
```

### package.json scripts

```json
{
  "scripts": {
    "test": "glubean run --config ci-config/default.yaml",
    "test:ci": "glubean run --config ci-config/ci.yaml",
    "test:staging": "glubean run --config ci-config/staging.yaml",
    "explore": "glubean run --config ci-config/explore.yaml"
  }
}
```

Then the underlying CI command becomes:

```bash
npm run test:ci
```

### Why this shape is preferred

- YAML files support comments — each option is self-documenting
- changing CI behavior means editing a yaml file, not rewriting a `package.json` script
- `--config` supports stacking (`--config base.yaml --config ci-overrides.yaml`)
- consistent with `glubean init` output — no disconnect between scaffolding and CI guidance
- the canonical command lives in one place
- workflow files stay short and easier to review

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
      - run: npm run test:ci
```

If the project already has a CI style, preserve the existing conventions instead of forcing this exact workflow.

## Faster path when initializing

If the user is still at project setup time and wants CI immediately, check whether `glubean init --hooks --github-actions` fits their workflow:

```bash
glubean init --hooks --github-actions
```

This generates `ci-config/*.yaml`, `package.json` scripts, and a GitHub Actions workflow in one step. Use this only when creating or re-initializing the project structure makes sense. Do not overwrite a hand-maintained CI setup without good reason.

## Cloud upload in CI

To enable Cloud upload, add the `cloud` section to `ci-config/ci.yaml`:

```yaml
run:
  testDir: ./tests
  failFast: true
  pretty: false

cloud:
  upload: true
  # projectId from env: GLUBEAN_PROJECT_ID

redaction:
  replacementFormat: simple
```

Required CI secrets:

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
