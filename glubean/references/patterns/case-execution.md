# Case Execution Boundary — requires / defaultRun

## Why this pattern

**Problem:** some contract cases are real business specs but physically can't run in CI — OAuth callbacks need a browser, Twilio SMS costs money, webhook tests need ngrok. Without a way to mark these, CI goes red and the user is surprised.

**Alternative:** put interactive cases in `explore/` — but that loses their value as specifications. They belong in `contracts/`.

**This pattern:** mark cases with `requires` (physical capability) and `defaultRun` (default policy). The runner skips non-matching cases explicitly with clear reporting. No silent skip.

## Two fields

### `requires` — what does this case physically need?

| Value | Meaning | Example |
|---|---|---|
| `"headless"` (default) | Fully automated, no human | Normal API tests |
| `"browser"` | Needs a real browser | OAuth callback, Stripe checkout, captcha |
| `"out-of-band"` | Needs out-of-band channel | Magic link (email), SMS OTP, webhook tunnel |

### `defaultRun` — should this case run automatically?

| Value | Meaning | Example |
|---|---|---|
| `"always"` (default) | Run whenever runner satisfies `requires` | Normal cases |
| `"opt-in"` | Skip unless explicitly requested | Real Twilio SMS ($), stress tests, Stripe charges |

**Auto-imply:** `requires !== "headless"` automatically sets `defaultRun: "opt-in"` unless you explicitly override. You almost never need to set `defaultRun` manually.

### `runnability.requireAttachment` — logical bare-run gate (v10 attachment-model)

Different from `requires` and `defaultRun`. Marks a case as "not bare-runnable" — the runner refuses to execute it without either an overlay or an explicit input.

```typescript
const requiresLogin = defineHttpCase<{ token: string }>({
  description: "Bare runs blocked — overlay or --input-json required.",
  needs: z.object({ token: z.string() }),
  headers: ({ token }) => ({ Authorization: `Bearer ${token}` }),
  expect: { status: 200, schema: ProfileSchema },
  runnability: { requireAttachment: true },
});
```

The three flags answer different questions:

| Flag | Question | Effect on bare run |
|---|---|---|
| `requires: "browser"` | What physical capability is needed? | Skipped unless `--include-browser` flag is set |
| `defaultRun: "opt-in"` | Should the case run by default? | Skipped unless explicitly requested |
| `runnability: { requireAttachment: true }` | Can the case run without setup? | **Hard error** unless overlay registered or `--input-json` supplied |

The three combine independently. A case can have all three: e.g. an OAuth case might be `requires: "browser"` + `requireAttachment: true` + auto-implied `defaultRun: "opt-in"`.

When a case marked `requireAttachment: true` is hit by a bare run with no attachment:
- With `needs` declared → suggest `--input-json '<JSON>'` or register an overlay.
- Without `needs` → only an overlay can run the case. Use `--force-standalone` for debug-only bypass.

See [attachment-model.md](attachment-model.md) for the full §6.3 dispatch table and the overlay pattern. See [runner-input.md](runner-input.md) for the CLI bypass channels.

## CLI flags

```bash
glubean run                         # default: headless + always only
glubean run --include-browser       # + browser cases
glubean run --include-out-of-band   # + out-of-band cases
glubean run --include-opt-in        # + headless opt-in cases (expensive)
```

**Local default = CI default = headless + always.** Agent, editor, script, and CI runs never pop a browser. Interactive cases require explicit `--include-browser`.

CI + `--include-browser` = **hard fail** (no browser available).

## Reporter output

Skipped cases are reported explicitly with reason and hint:

```
contracts/auth/google-callback.contract.ts
  ✓ invalidToken (3 ms)
  ⊘ success — skipped (requires: browser, use --include-browser to run)

Result: 1 passed, 1 skipped (1 require explicit opt-in), 0 failed
```

Green never hides a skip.

## Examples

### OAuth callback — requires: "browser"

```typescript
// Setup (once per file): create the scoped instance.
const oauthApi = contract.http.with("oauth", { client: oauthClient });

export const googleCallback = oauthApi("google-callback", {
  endpoint: "POST /auth/google/callback",
  cases: {
    success: {
      description: "Valid Google token returns app JWT.",
      requires: "browser",
      // defaultRun auto-implied: "opt-in"
      expect: { status: 200 },
    },
    invalidToken: {
      description: "Forged token is rejected.",
      // No requires — default headless, runs everywhere
      body: { token: "fake" },
      expect: { status: 401 },
    },
  },
});
```

### Real Twilio SMS — headless but opt-in

```typescript
const notificationsApi = contract.http.with("notifications", { client: api });

export const sendSms = notificationsApi("send-sms", {
  endpoint: "POST /notifications/sms",
  cases: {
    realSend: {
      description: "Real Twilio SMS delivery.",
      defaultRun: "opt-in",  // headless but costs money
      body: { phone: "+1234567890", message: "test" },
      expect: { status: 202 },
    },
  },
});
```

Run with: `glubean run --include-opt-in`

### Webhook with ngrok — requires: "out-of-band"

```typescript
const webhookApi = contract.http.with("webhook", { client: api });

export const stripeWebhook = webhookApi("stripe-webhook", {
  endpoint: "POST /webhooks/stripe",
  cases: {
    paymentSuccess: {
      description: "Stripe payment_intent.succeeded webhook.",
      requires: "out-of-band",
      // needs ngrok tunnel locally
      expect: { status: 200 },
    },
  },
});
```

### Workflow-level (entire workflow is interactive)

Workflows compose existing cases via `.call(id, ref, bindings)`. `requires` / `defaultRun` are case-level fields, not workflow-level fields. If an entire workflow is interactive, tag it clearly and keep the capability requirement on the referenced cases; use `skip: "reason"` for workflows that should not run at all yet.

```typescript
// Assumes authorize / callback / verifySession contracts are defined elsewhere.
export const oauthFlow = workflow("oauth-flow")
  .meta({ tags: ["requires:browser"], extensions: { "x-requires": "browser" } })
  .call("authorize", authorize.case("success"), {
    out: (_s, res) => ({ code: res.body.code as string }),
  })
  .call("callback", callback.case("success"), {
    in: (s) => ({ body: { code: s.code } }),
    out: (_s, res) => ({ sessionToken: res.body.token as string }),
  })
  .compute("auth-header", (s) => ({ ...s, authHeader: `Bearer ${s.sessionToken}` }))
  .call("verify-session", verifySession.case("success"), {
    in: (s) => ({ headers: { Authorization: s.authHeader as string } }),
  });
```

## Auto-tags

The SDK automatically adds tags based on `requires` and `defaultRun`:
- `requires: "browser"` → tag `requires:browser`
- `requires: "out-of-band"` → tag `requires:out-of-band`
- `defaultRun: "opt-in"` → tag `default-run:opt-in`

These work with existing tag-filter workflows: `glubean run --tag requires:browser`.

## When NOT to use

- **Don't** mark `/me`, `/projects`, or business contracts as `requires: "browser"` just because the project uses OAuth login. Those contracts need *any* authenticated token — use [session-auth](session-auth.md) to provide one via bypass.
- **Don't** use `requires` for flaky tests — flakiness is a quality issue, not a capability issue.
- **Don't** use `defaultRun: "opt-in"` for slow tests unless they're actually expensive or have side effects — slow is annoying but not dangerous.
