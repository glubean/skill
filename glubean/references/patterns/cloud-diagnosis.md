# Cloud Diagnosis - Fast Failure Triage from a Run ID

## Why this pattern

**Problem:** after CI or Cloud fails, users often paste a long log or screenshot and ask what happened. Logs prove that a run failed, but they are a poor diagnostic interface for agents: important assertion details, traces, and test IDs are buried in text.

**This pattern:** when the user provides a Glubean Cloud run ID, Cloud run URL, or asks an agent to diagnose a failed uploaded run, pull the smallest useful failure summary from the Glubean Open API first. Group failures by cause, cite the exact evidence, and propose the next action without dumping the whole event stream.

## When to use this

- User pastes a Cloud run ID such as `clr_...`
- User pastes a Glubean Cloud run URL
- User says "why did this Glubean run fail?", "diagnose this CI run", "fetch the failures", or "look at the uploaded run"
- User provides a project token or API key with read access
- CI failed and the local project is not available, too slow to run, or not the source of truth for that failure

Do not use this for a fresh local test-writing loop. Local authoring still uses `glubean_run_local_file`; Cloud diagnosis is for uploaded or remote run evidence.

## Required inputs

- `runId` or a URL that contains a run ID
- `token` with read access
  - A `glb_` token scoped to `runs:read` (or a personal `glb_` token that inherits read access)
  - The token's org must own the run's project
- `apiUrl`
  - Default: `https://api.glubean.com`
  - Override only when the user gives a different API host

Never ask for write or manage scopes for diagnosis.

## Tool order

1. **Dedicated failure summary, if available**
   - Prefer a focused failures tool such as `glubean_cloud_get_failures` when the MCP server exposes it.
   - Otherwise call the HTTP endpoint directly if the current agent environment can send an `Authorization` header:

   ```http
   GET {apiUrl}/open/v1/runs/{runId}/failures
   Authorization: Bearer {token}
   ```

   This endpoint is designed for agent triage: it returns only failing tests, normalized failure reasons, and a few recent events.

2. **Cloud run/events fallback**
   - Use `glubean_open_get_run` to confirm status and summary.
   - Use `glubean_open_get_run_events` to page through events.
   - Fetch the smallest useful slice first:
     - `type: "result"` to identify failed tests when available
     - `type: "assert"` for failed assertion details
     - `type: "trace"` only when body shape, status, headers, or timing matter
     - `type: "log"` only when assertions and traces do not explain the failure
   - Stop when you have enough evidence to explain the failure. Do not retrieve or paste every event by default.

3. **No API path available**
   - Ask for one of:
     - a read-only project token and run ID
     - the focused `/failures` response JSON
     - the relevant `.result.json`
   - Do not pretend to diagnose from a pass/fail status alone.

## Secret handling

- Treat project tokens and API keys as secrets.
- Do not echo token values back to the user.
- Do not write tokens into files, command history, examples, or generated docs.
- When summarizing request setup, say "read-only platform token" or `glb_...`, not the full value.
- If an API error suggests the token is invalid, say the class of problem (`401`, `403`, wrong project, missing `runs:read`) without revealing the token.

## Diagnosis workflow

1. Extract the `runId` from the user's message or URL.
2. Confirm whether a read-only token is available.
3. Fetch focused failures first.
4. If the run is queued or running, report that it is not ready and do not fabricate causes.
5. Group failures by reason:
   - assertion mismatch
   - exception
   - timeout
   - auth or permission setup
   - network or environment
   - schema drift
   - data or state leakage
   - unknown
6. For each group, cite the evidence:
   - failed test ID/name
   - reason kind/message
   - actual vs expected when present
   - relevant last event or trace fact
7. Propose the next action and owner:
   - fix test assertion
   - fix auth/env setup
   - update project context/spec
   - fix implementation
   - rerun the same test locally
   - rerun the CI/Cloud profile

## Output shape

Use this structure:

```markdown
## Diagnosis

Status: failed, 3/14 tests failed.

### Main pattern
Most failures are assertion mismatches in auth-boundary tests.

### Failure groups
- auth-boundary assertions: 2 tests
  Evidence: `delete-user-non-admin` expected 403, actual 200.
  Likely cause: role enforcement is missing or the test token has admin scope.
  Next action: verify the token role, then inspect the DELETE middleware.

- schema drift: 1 test
  Evidence: `get-user-profile` expected `displayName`, response has `name`.
  Likely cause: API response shape changed or the test schema is stale.
  Next action: compare source/OpenAPI with the trace before changing the assertion.

### What I would not change yet
Do not weaken the status assertions until the role behavior is confirmed.
```

Keep the summary short. The user wants a diagnosis, not an event dump.

## Status-code handling

- `200`: diagnose from the returned failures; if `failures` is empty, say the run has no failing tests in the failure summary.
- `401`: token missing or invalid.
- `403`: token lacks `runs:read`, belongs to the wrong project, or the user is not authorized for the run.
- `404`: run not found, not uploaded, in another project, or not finished yet.

## Agent behavior rules

- Prefer Cloud evidence over pasted terminal logs when both are available.
- Prefer focused failure summaries over full event streams.
- Never use Cloud access to mutate data during diagnosis.
- Do not turn a Cloud failure into local code edits unless the user asks you to fix it and the relevant repo is available.
- If recommending a test change, apply the repair rules: do not weaken assertions just to make the next run green.
- If the diagnosis depends on business rules, point to `GLUBEAN.md`, `context/`, contracts, or source code as the next evidence to check.
