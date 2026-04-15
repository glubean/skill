# MCP Reference

Glubean ships an MCP server (`@glubean/mcp`) that exposes structured tools for agent-driven test execution. This is the **recommended way for agents to run and fix tests** — not the CLI.

## Why MCP instead of CLI

The CLI is designed for humans and CI pipelines: it writes human-readable text to stdout.

The MCP tools return **structured JSON** optimized for agents:

| What you get via MCP | What you get via CLI |
|---|---|
| Assertions with `passed`, `actual`, `expected` | Diff text in console output |
| HTTP traces with `responseSchema` (inferred JSON Schema) | `--verbose` text dump |
| `responseBody` truncated to agent context budget | Full body printed to terminal |
| Per-test `logs`, `error.message`, `error.stack` | Interleaved console lines |
| `summary.passed / summary.failed` as numbers | Exit code + printed summary |

When an agent uses the CLI, all the structured failure data that Glubean captures is discarded — the agent can only read the text output. The MCP tools exist specifically so agents can read structured failures and fix tests without guessing.

**Rule:** always prefer MCP when available. Fall back to CLI only when MCP is not available in the current environment (e.g., inside a CI container that cannot run stdio MCP).

## Setup

### Auto-configure for supported clients

```bash
npx glubean@latest config mcp
```

The CLI prompts you to choose a client, then writes the config automatically:

| Client | Config location |
|---|---|
| Claude Code | user-scope (`claude mcp add glubean -s user`) |
| Codex (OpenAI) | `~/.codex/config.toml` |
| Cursor | `.cursor/mcp.json` in the project root |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |

Restart the client after running `glubean config mcp`.

### Manual JSON config (any MCP-compatible client)

If your client is not in the list above but supports MCP, add this block to its MCP config file:

```json
{
  "mcpServers": {
    "glubean": {
      "command": "npx",
      "args": ["-y", "@glubean/mcp@latest"]
    }
  }
}
```

This is the standard MCP server config format used by the MCP spec. Most clients that support MCP accept this shape (the key wrapping differs by client — check your client's docs for where this block goes).

### Codex TOML format

Codex uses TOML instead of JSON. The equivalent entry in `~/.codex/config.toml`:

```toml
[mcp_servers.glubean]
command = "npx"
args = ["-y", "@glubean/mcp@latest"]
```

## Available tools

### Local execution (primary agent workflow)

#### `glubean_run_local_file`

Run tests from a file and return structured results.

```
filePath       required  Path to test file (e.g. explore/users.test.ts)
filter         optional  Substring match on id, name, or tag
includeLogs    optional  Include ctx.log events (default: true)
includeTraces  optional  Include HTTP traces with responseSchema (default: false)
stopOnFailure  optional  Stop after first failure (default: false)
concurrency    optional  Parallel workers (default: 1, max: 16)
envFile        optional  Override .env path
```

Returns: `{ summary, results[] }` where each result has:
- `success`, `durationMs`, `id`, `name`
- `assertions[]` — each with `passed`, `message`, `actual`, `expected`
- `logs[]` — each with `message`, `data`
- `traces[]` — each with `responseSchema`, `responseBody`, `status`, `headers`, `durationMs` (only when `includeTraces: true`)
- `error` — `{ message, stack }` on unhandled exceptions

**When to set `includeTraces: true`:** when writing a new test and you need to know the response shape, or when an assertion on a field name is failing. The `responseSchema` tells you what the API actually returns — use it to fix field names without guessing.

#### `glubean_discover_tests`

Extract test exports from a file without running them.

```
filePath  required  Path to test file
```

Returns: `{ tests[] }` where each test has `id`, `exportName`, `name`, `tags`, `skip`, `only`.

Use this before running to check what tests exist in a file, or to verify a test ID before filtering.

#### `glubean_list_test_files`

Scan a directory and return all test file paths.

```
dir   optional  Project root (default: cwd)
mode  optional  "static" (default) | "runtime"
```

Returns: `{ files[], fileCount, warnings }`.

Use this to discover what test files exist in the project before deciding which file to run.

#### `glubean_get_last_run_summary`

Return a lightweight summary of the most recent `glubean_run_local_file` call. No input required.

Returns: `{ summary, testIds[], eventCounts }`.

Use this after a run to quickly check pass/fail counts without re-reading the full results.

#### `glubean_get_local_events`

Return filtered events from the most recent `glubean_run_local_file` call.

```
type    optional  Filter by type: "result" | "assertion" | "log" | "trace"
testId  optional  Filter to a single test
limit   optional  Max events returned (default: 200, max: 2000)
```

Returns: `{ availableTotal, returned, events[] }`.

Use this when you need to drill into a specific test's trace or assertion without retrieving the full run snapshot. Useful when a run contains many tests but you only need details for one.

#### `glubean_get_metadata`

Generate project metadata (equivalent to `metadata.json`) in memory without writing to disk.

```
dir          optional  Project root (default: cwd)
mode         optional  "runtime" (default) | "static"
generatedBy  optional  Override the generatedBy field
```

Returns: `{ metadata }` — full bundle metadata including test count, file hashes, and tags.

Use this for coverage audits and gap reports: inventory files and tags first, then cross-reference the result with `context/` or OpenAPI docs before opening many test files by hand.

### Cloud tools (require Glubean Cloud project)

These tools call the Glubean Open Platform API. They require `apiUrl`, `token`, `projectId`, and/or `bundleId`.

| Tool | What it does |
|---|---|
| `glubean_open_trigger_run` | Trigger a remote run for a project bundle |
| `glubean_open_get_run` | Poll run status by run ID |
| `glubean_open_get_run_events` | Page through run events (log/assertion/trace/result) |

Use these when the user wants to trigger a Cloud run from within the agent conversation, or to tail a run triggered by CI.

## Agent run loop

The standard MCP-powered write/run/fix loop:

1. **Write** the test file.
2. **Run** with `glubean_run_local_file` — `includeLogs: true`, `includeTraces: false`.
3. If a test fails with a field name error, re-run with `includeTraces: true` and read `responseSchema` to find the correct field.
4. If the failure is unclear, read [patterns/repair.md](patterns/repair.md) and classify it before editing.
5. **Fix** the assertion, auth config, context, or implementation.
6. **Re-run** until `summary.failed === 0`.

Prefer `filter` to run only the test you are working on — it is faster and keeps the result set small.

## Trace header filtering

By default, MCP traces strip most headers to save context tokens. Only these are kept:

| Direction | Default kept headers |
|---|---|
| Request | `content-type`, `authorization` |
| Response | `content-type`, `set-cookie`, `location` |

All other headers are discarded before the trace reaches the agent.

**This means the agent cannot see headers like `x-processing-duration`, `x-request-id`, `x-ratelimit-remaining`, or `server-timing` unless the user configures them.**

### Configuring additional headers

Add to `package.json`:

```json
{
  "glubean": {
    "mcp": {
      "trace": {
        "keepResponseHeaders": [
          "content-type", "set-cookie", "location",
          "x-processing-duration", "x-request-id", "server-timing"
        ]
      }
    }
  }
}
```

The list replaces the default — include the defaults if you still want them.

### Agent behavior

- When the agent needs header data it cannot see in traces (e.g. for metrics, debugging, rate limit tracking), ask the user: "Does your API return useful headers like `x-processing-duration` or `server-timing`?"
- If yes, suggest adding them to `keepResponseHeaders` in `package.json` so future traces include them.
- **Test code always has full access to `res.headers`** regardless of this config. The filtering only affects what the agent sees via MCP traces.

## When CLI is appropriate

| Situation | Use |
|---|---|
| Agent in local project, MCP available | **MCP** (`glubean_run_local_file`) |
| Agent exploring API, needs response shape | **MCP** (with `includeTraces: true`) |
| CI pipeline (`npm run test:ci`) | **CLI** (`glubean run --config ci-config/ci.yaml`) |
| Cloud upload from CI | **CLI** (`glubean run tests/ --upload`) |
| MCP not available in environment | **CLI** (fallback only) |

See [ci-workflow.md](ci-workflow.md) for CI setup.
