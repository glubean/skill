# Glubean CLI Reference

> **Skill install:** The Glubean skill is now installed via Agent Skills standard: `npx skills add glubean/skill`. SDK reference docs are bundled with the skill — no separate download needed.

## Commands Overview

| Command | Purpose |
|---------|---------|
| `glubean run` | Run tests locally (a profile, a target, or both) |
| `glubean ci run` | Run the `ci` profile (= `glubean run --profile ci`) |
| `glubean scan` | Generate metadata.json from test files |
| `glubean login` | Authenticate with Glubean Cloud |
| `glubean init` | Initialize a new test project (interactive wizard) |
| `glubean redact` | Preview redaction on a result JSON file |
| `glubean config mcp` | Install MCP server via `npx add-mcp` (auto-detects installed AI tools) |
| `glubean spec split` | Dereference $refs and split OpenAPI spec into per-endpoint files |
| `glubean patch` | Merge an OpenAPI spec with its `.patch.yaml` overlay |
| `glubean validate-metadata` | Validate metadata.json against local test files |

---

## glubean run

Run tests from a file, directory, or glob pattern.

```bash
glubean run                              # Run the `local` profile (from glubean.yaml)
glubean run --profile ci                 # Run a named profile
glubean run tests/api/                   # Run a directory (ad-hoc, no profile)
glubean run tests/api/health.test.ts     # Run a single file
glubean run "tests/**/*.test.ts"         # Run by glob pattern
```

### Filtering

```bash
glubean run --filter smoke               # Match test name or ID substring
glubean run --tag api                    # Match exact tag
glubean run --tag api --tag auth         # Multiple tags (OR by default)
glubean run --tag api --tag auth --tag-mode and  # All tags must match
glubean run --pick basic,edge-case       # Select specific test.pick examples by key
```

### Output & Debugging

```bash
glubean run --verbose                    # Show traces, assertions in console
glubean run --log-file                   # Write logs to <testfile>.log
glubean run --log-file --pretty          # Pretty-print JSON in log files
glubean run --result-json                # Write results to .result.json
glubean run --result-json results.json   # Write to custom path
glubean run --reporter junit             # JUnit XML output
glubean run --reporter junit:report.xml  # JUnit to specific file
glubean run --emit-full-trace            # Include full request/response in traces
glubean run --inspect-brk                # Attach V8 debugger (pauses until attached)
```

### Failure Handling

```bash
glubean run --fail-fast                  # Stop on first failure
glubean run --fail-after 3               # Stop after 3 failures
```

For CI mode (fail-fast + junit reporter), define a `ci` profile in
`glubean.yaml` and run `glubean ci run` — there is no `--ci` flag.

### Cloud Upload

```bash
glubean run --upload                     # Run + upload results to Cloud
glubean run --upload --project proj_abc  # Specify project (or GLUBEAN_PROJECT_ID env)
glubean run --upload --token gpt_xxx     # Specify token (or GLUBEAN_TOKEN env)
```

### Profile & config

```bash
glubean run --profile ci                 # Resolve a named profile from glubean.yaml
glubean run --profile ci --suite tests   # Narrow a multi-suite profile to one suite
glubean run --env-file .env.staging      # Use alternate .env file
glubean run --config ./other/glubean.yaml  # Load an alternate glubean.yaml
glubean run --trace-limit 50             # Keep up to 50 trace files per test (default: 20)
```

---

## glubean ci run

Run the `ci` profile from `glubean.yaml`. Equivalent to `glubean run --profile ci`.
Suites, fail-fast, reporters, and thresholds all come from `profiles.ci` — see
[ci-workflow.md](ci-workflow.md).

```bash
glubean ci run                           # Run the ci profile
glubean ci run --upload                  # ...and upload results to Cloud
glubean ci run --suite tests             # Narrow to one suite
```

---

## glubean scan

Generate metadata.json from test files. Used for inspecting test inventory and as a CI drift gate (with `validate-metadata`).

```bash
glubean scan                             # Scan current directory
glubean scan --dir ./tests               # Scan specific directory
glubean scan --out metadata.json         # Custom output path
```

---

## glubean login

Authenticate with Glubean Cloud. Stores credentials locally.

```bash
glubean login                            # Interactive login
```

---

## glubean init

Initialize a new test project with interactive wizard.

```bash
glubean init                             # Start wizard in current directory
```

Creates: `package.json`, `glubean.yaml` (suites + `local`/`ci`/`explore` profiles), `tests/`, `explore/`, `types/`, `.env`, `.env.secrets`, `.gitignore`.

---

## glubean redact

Preview redaction on a result JSON file. Applies configured redaction rules to see what would be masked.

```bash
glubean redact                           # Redact default glubean-run.result.json
glubean redact -i results.json           # Redact specific file
glubean redact --stdout                  # Output to stdout
```

---

## glubean config mcp

Configure the Glubean MCP server for AI coding tools.

```bash
glubean config mcp                            # Install via npx add-mcp (auto-detects all tools)
glubean config mcp --remove                   # Remove MCP configuration
glubean config mcp --remove --target cursor   # Remove for a specific tool
```

---

## glubean spec split

Dereference `$ref`s and split an OpenAPI spec into per-endpoint files for AI consumption.

```bash
glubean spec split openapi.yaml          # Split to <name>-endpoints/ directory
glubean spec split openapi.yaml -o out/  # Custom output directory
```

---

## glubean patch

Merge an OpenAPI spec with its `.patch.yaml` overlay and write the complete spec.

```bash
glubean patch openapi.yaml               # Auto-discover .patch.yaml
glubean patch openapi.yaml --patch custom.patch.yaml
glubean patch openapi.yaml -o merged.json
glubean patch openapi.yaml --stdout      # Write to stdout
```

---

## glubean validate-metadata

Validate metadata.json against local test files to detect drift.

```bash
glubean validate-metadata                # Validate in current directory
glubean validate-metadata -d ./tests     # Specify project root
```

---

## Environment Variables

| Variable | Purpose | Used by |
|----------|---------|---------|
| `GLUBEAN_TOKEN` | Auth token (`gpt_` prefix) | `run --upload`, `ci run --upload` |
| `GLUBEAN_PROJECT_ID` | Project short ID (e.g. `prj_…`) | `run --upload`, `ci run --upload` |
| `GLUBEAN_API_URL` | API server URL (default: `https://api.glubean.com`) | cloud uploads |

---

## Workflow: AI-Assisted Test Writing

```bash
# 1. Write tests (manually or with AI — point AI at your OpenAPI spec directly)

# 2. Run and verify
glubean run --verbose

# 3. Upload results
glubean run --upload
```
