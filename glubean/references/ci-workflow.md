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

1. Define **profiles** in `glubean.yaml` (one named run plan per scenario — `local`, `ci`, …).
2. Run a profile by name: `glubean ci run` (shorthand for `glubean run --profile ci`).
3. Make CI call `glubean ci run`.

### glubean.yaml profiles

`glubean init` generates `glubean.yaml` with `local` + `ci` profiles. In an
already-initialized project, add a profile if one doesn't exist. If core
project structure is still missing, run `glubean init` first instead of
hand-creating around a half-initialized repo.

```yaml
version: 1

defaults:
  redaction:
    replacementFormat: simple

suites:
  tests:
    target: ./tests
    kinds: [test]
  explore:
    target: ./explore
    kinds: [test]

profiles:
  local:                 # bare `glubean run` / npm test
    suites: [tests]
  ci:                    # `glubean ci run` / npm run test:ci
    suites: [tests]
    execution:
      failFast: true
    reporters:
      junit: .glubean/results/junit.xml
      resultJson: .glubean/results/ci.result.json
  explore:
    suites: [explore]
```

### package.json scripts

```json
{
  "scripts": {
    "test": "glubean run --profile local",
    "test:ci": "glubean ci run",
    "explore": "glubean run --profile explore"
  }
}
```

For a staging environment, switch env files at run time — test code and
profiles never change:

```json
"test:staging": "glubean run --profile ci --env-file .env.staging"
```

Then the underlying CI command becomes:

```bash
npm run test:ci
```

### Why this shape is preferred

- one config source (`glubean.yaml`) — no split between `package.json` and separate config files
- profiles are named, self-documenting run plans; CI just picks one by name
- `glubean ci run` matches `glubean run --profile ci` run locally — no drift between local and CI
- changing CI behavior means editing the `ci` profile in `glubean.yaml`, not rewriting a `package.json` script
- consistent with `glubean init` output — no disconnect between scaffolding and CI guidance

## GitHub Actions

If the user wants GitHub Actions, prefer a workflow that calls the script (or `glubean ci run` directly):

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
      - run: npx glubean ci run
```

If the project already has a CI style, preserve the existing conventions instead of forcing this exact workflow.

## Faster path when initializing

If the user is still at project setup time and wants CI immediately, check whether `glubean init --hooks --github-actions` fits their workflow:

```bash
glubean init --hooks --github-actions
```

This generates `glubean.yaml` (with `local` + `ci` profiles), `package.json` scripts, and a GitHub Actions workflow in one step. Use this only when creating or re-initializing the project structure makes sense. Do not overwrite a hand-maintained CI setup without good reason.

## Cloud upload in CI

`glubean ci run` resolves the `ci` profile, so add `--upload`:

```bash
glubean ci run --upload
```

Provide the project ID via the committed `.env` (`GLUBEAN_PROJECT_ID=prj_...`)
or a profile's `upload.projectAlias`; store the token in the CI secret store.

Required CI secret:

- `GLUBEAN_TOKEN` (the project ID is not a secret — keep it in `.env` or `glubean.yaml`)

Store the token in the CI provider's secret store, not in the repo. Because
`ci run` resolves a profile, your `defaults.redaction` rules are applied before
upload.

## Metadata and validation

If the project uses metadata sync as a gate, also consider:

```bash
glubean validate-metadata
```

Use it when metadata drift matters to the team's workflow. Do not add it blindly if the project does not use metadata yet.

## Agent behavior

When creating CI for the user:

1. Reuse the repo's existing CI conventions if they already exist.
2. Add or update the `ci` profile in `glubean.yaml` (and matching `package.json` scripts) before editing the CI workflow file.
3. Keep CI focused on `tests/`, not `explore/`.
4. Prefer stable output locations for result JSON and JUnit XML (set them in `reporters`).
5. Ask before adding Cloud upload if credentials are not already configured.
6. After creating CI, explain the profile, the script names, and the artifacts they will produce.
