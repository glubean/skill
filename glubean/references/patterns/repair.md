# Repair Loop — Fix the Test Without Weakening It

## Why this pattern

**Problem:** when a test fails, agents often "fix" it by removing assertions, switching to status-only checks, or broadening schemas until the test passes. That hides real regressions and slowly erodes suite quality.

**This pattern:** inspect the structured failure first, classify the failure mode, then decide whether the fix belongs in the test, auth setup, context/spec, or implementation. Tighten the test only when the behavior is confirmed.

## Use when

- `glubean_run_local_file` returns a failed assertion
- A trace shows the response shape changed unexpectedly
- Auth works in one environment but not another
- The run output is noisy and you need the typed failure, not terminal text

## Common failure modes

### Repair drift

The API behavior changed, but the test is still asserting the old contract.

Signs:
- `actual` and `expected` disagree on a field the API is supposed to own
- `responseSchema` from traces no longer matches the test's assumptions
- the same endpoint passes in docs or source but fails in the test

Action:
- Re-read the trace, OpenAPI/spec, or source of truth
- Confirm whether the implementation changed intentionally
- Update the assertion or schema only after the new behavior is confirmed

### Auth entropy

The request is fine, but the auth setup is wrong or incomplete.

Signs:
- 401/403 failures across many endpoints
- wrong header name, wrong secret name, expired token, or missing role
- a client change fixed some tests and broke others

Action:
- Re-check the configured client, env keys, and auth strategy
- Compare the request headers in the trace with the intended auth pattern
- Fix configuration before touching endpoint assertions

### Spec amnesia

The test forgot a business rule that should still be enforced.

Signs:
- the test passes after you remove an assertion, but that assertion represented a real rule
- the project context or `GLUBEAN.md` mentions a rule that the test no longer checks
- a negative path disappeared because the first green run felt "good enough"

Action:
- Re-read `GLUBEAN.md`, `context/`, or the route/source notes
- Restore the missing business assertion or error case
- If the rule is new, add it to `GLUBEAN.md` so the next session keeps it

### Terminal fog

The console output is too noisy to identify the actual failure.

Signs:
- long terminal logs with no obvious assertion context
- multiple unrelated messages hide the first useful error
- you are guessing from text instead of looking at typed run events

Action:
- Use MCP structured output, especially assertion `actual` / `expected`
- Re-run with `includeTraces: true` when field names or body shape are unclear
- Inspect the relevant test's events instead of scanning the whole log

## Repair workflow

1. Identify the first failing assertion or typed error.
2. Classify it: drift, auth entropy, spec amnesia, or terminal fog.
3. Re-read the smallest useful evidence: trace, schema, context file, or source note.
4. Decide whether the fix belongs in auth config, test assertions, context, or implementation.
5. If the only obvious "fix" is to make the assertion weaker, stop and verify that the behavior actually changed.
6. Make the smallest change that restores confidence.
7. Re-run the same file or case before moving on.

## Self-check before committing a repair

- Am I deleting an assertion because it failed, or because it is truly obsolete?
- Did I confirm the response shape from a trace or source, not from guesswork?
- Did I preserve the business rule, even if the payload shape changed?
- Would this same change still catch a regression next week?

## Good repair examples

- Update a field name after `responseSchema` proves the API renamed it
- Restore `403` coverage after reading a role rule in `GLUBEAN.md`
- Fix the configured auth client instead of changing every protected test to public
- Tighten a schema after the API adds a required field

## Bad repair examples

- Replace schema validation with `toBeDefined()`
- Delete duplicate-email coverage because it is flaky
- Change a 401 assertion to "any non-200"
- Keep broadening a matcher until the test stops failing
