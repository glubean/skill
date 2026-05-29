# Environments — Running Tests Against Multiple Targets

## Why this pattern

**Problem:** tests hardcode one base URL and one set of credentials. When the user needs to run against staging, production, or a teammate's local server, they manually edit `.env` and hope they remember to revert.
**Alternative:** use shell scripts or CI-only env injection — but then local and CI diverge, and developers can't easily switch targets.
**This pattern:** one `.env` + `.env.secrets` pair per environment, switched with `--env-file` (or a `package.json` script per environment). Test code never changes. The runner resolves the right file at runtime.

## File naming convention

```
.env                    # default (local dev)
.env.secrets            # default secrets (gitignored)
.env.staging            # staging overrides
.env.staging.secrets    # staging secrets (gitignored)
.env.production         # production overrides
.env.production.secrets # production secrets (gitignored)
```

Rule: every `.env.{name}` has a matching `.env.{name}.secrets`. The runner loads both automatically.

## Switching environments

CLI — pass the env file at run time:

```bash
glubean run --profile ci --env-file .env.staging
```

package.json — one script per environment. The profile stays the same; only
the env file changes:

```json
{
  "scripts": {
    "test": "glubean run --profile local",
    "test:staging": "glubean run --profile ci --env-file .env.staging",
    "test:prod": "glubean run --profile ci --env-file .env.production"
  }
}
```

`--env-file` is the switch — test code, `configure()`, and your `glubean.yaml`
profiles never change.

## Host environment variable passthrough

Values in `.env` files support `${NAME}` syntax to reference host environment variables:

```
# .env.ci
BASE_URL=${CI_API_BASE_URL}
```

```
# .env.ci.secrets
API_KEY=${CI_API_KEY}
```

Lookup order: same-pair values first (`.env` + `.env.secrets` are merged before expansion, so `.env.secrets` can reference a key defined in `.env` and vice versa), then `process.env`, then empty string.

```
# .env
BASE_URL=https://api.staging.example.com

# .env.secrets — may reference keys from .env
WEBHOOK_URL=${BASE_URL}/webhook
```

**Agent behavior:** when setting up `.env.secrets` or a new environment file, ask the user whether they already have relevant values in host environment variables (e.g. from a shell profile, CI provider, or secrets manager). If yes, use `${HOST_VAR}` references instead of asking them to paste raw values. Most users don't know this feature exists.

This is especially useful for:
- **CI**: secrets injected by the CI provider (GitHub Actions secrets, etc.) flow into `.env` without hardcoding
- **Local dev**: reference machine-level env vars shared across projects

When writing `.env` files for the user, add comments explaining which host variables are expected:

```
# .env.ci.secrets
# Set these in your CI provider's secret store:
API_KEY=${CI_API_KEY}
AUTH_TOKEN=${CI_AUTH_TOKEN}
```

## What stays the same across environments

Test code and `configure()` never change. They use `{{KEY}}` which resolves from whichever `.env` pair is active:

```typescript
export const { http: api } = configure({
  http: { prefixUrl: "{{BASE_URL}}" },
});
```

`{{BASE_URL}}` resolves to different values depending on which env file is loaded. No if/else, no env detection code.

## Extension environment switching

The VS Code extension reads `.glubean/active-env` to know which environment is active. Users switch via the status bar. The CLI respects the same file when `--env-file` is not explicitly passed.
