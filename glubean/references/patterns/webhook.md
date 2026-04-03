# Webhook Delivery Testing

Verify that a service delivers webhooks correctly: right event, right payload, valid signature.

## Why this pattern

**Problem:** webhook testing requires your test to *receive* an HTTP callback from an external service. The test machine is usually behind NAT or a firewall — the service can't reach it directly.
**Alternative:** skip webhook testing, or manually check delivery logs. Both leave a gap in coverage.
**This pattern:** set up a channel proxy (tunnel) so the external service can reach a local server inside your test. Then: register → trigger → wait → verify → cleanup.

## The flow

```text
setup channel → register endpoint → trigger event → wait for delivery → verify payload + signature → cleanup
```

This maps directly to a builder test with `.setup()`, `.step()`, and `.teardown()`.

## Channel proxy options

The proxy bridges the external service to your local test server. Choose based on your constraints:

| Proxy | How it works | Best for |
|-------|-------------|----------|
| **smee.io** | GitHub-hosted event relay. No install, free. `smee-client` npm package forwards to localhost. | Quick setup, GitHub/Stripe webhooks |
| **ngrok** | Binary tunnel, stable URLs on paid tier. | Production-like testing, stable URLs |
| **Cloudflare Tunnel** | Free, needs `cloudflared` installed. | Teams already on Cloudflare |
| **localtunnel** | Open source, no account. Less reliable. | Disposable one-off tests |
| **Delivery log API** | No proxy needed — poll the service's delivery history API (Stripe, GitHub, Slack have these). | When the service exposes delivery logs |

For most Glubean tests, **smee.io** is the simplest default. No binary, no account, one npm dependency.

## Implementation

### Builder structure

```typescript
import { test } from "@glubean/sdk";
import SmeeClient from "smee-client";
import { api } from "../../config/api.ts";

type HookPayload = { headers: Record<string, string>; body: string };

export const webhookDelivery = test("webhook-delivery")
  .meta({ name: "Webhook end-to-end delivery", tags: ["webhook"] })

  .setup(async ({ vars, log }) => {
    const smeeUrl = vars.require("SMEE_URL");

    // Promise that resolves when the webhook arrives
    let resolveHook!: (p: HookPayload) => void;
    const hookReceived = new Promise<HookPayload>((res) => {
      resolveHook = res;
    });

    // Local HTTP server on a random port
    const { createServer } = await import("node:http");
    const server = await new Promise<import("node:http").Server>((resolve) => {
      const s = createServer((req, res) => {
        let body = "";
        req.on("data", (c) => (body += c));
        req.on("end", () => {
          const headers: Record<string, string> = {};
          for (const [k, v] of Object.entries(req.headers)) {
            if (typeof v === "string") headers[k] = v;
          }
          resolveHook({ headers, body });
          res.end("ok");
        });
      });
      s.listen(0, () => resolve(s));
    });

    const port = (server.address() as { port: number }).port;
    log(`Local server listening on :${port}`);

    // Smee tunnel: external service → smee → localhost
    const smee = new SmeeClient({
      source: smeeUrl,
      target: `http://localhost:${port}`,
    });
    const events = smee.start();
    log(`Tunnel: ${smeeUrl} → localhost:${port}`);

    return { server, events, hookReceived, smeeUrl };
  })

  .step("register endpoint", async ({ log }, state) => {
    // Register a webhook endpoint on the external service
    const endpoint = await api
      .post("webhooks", { json: { url: state.smeeUrl, events: ["order.created"] } })
      .json<{ id: string; secret: string }>();

    log(`Registered: ${endpoint.id}`);
    return { ...state, endpointId: endpoint.id, webhookSecret: endpoint.secret };
  })

  .step("trigger event", async ({ log }, state) => {
    // Perform the action that triggers a webhook delivery
    await api.post("orders", { json: { item: "test", qty: 1 } }).json();
    log("Triggered order.created event");
    return state;
  })

  .step("verify delivery", async ({ expect, log }, state) => {
    // Wait for the Promise from setup to resolve
    const { headers, body } = await state.hookReceived;
    const payload = JSON.parse(body);

    expect(payload.type).toBe("order.created");
    expect(headers["x-webhook-signature"]).toBeDefined();

    // Verify signature if the service provides one
    // verifySignature(body, headers["x-webhook-signature"], state.webhookSecret);

    log(`Event: ${payload.type}`);
    log("Signature present ✓");
  })

  .teardown(async ({ log }, state) => {
    if (state.endpointId) {
      await api.delete(`webhooks/${state.endpointId}`).json();
      log(`Deleted endpoint: ${state.endpointId}`);
    }
    state.events?.close();
    state.server?.close();
  });
```

### Key decisions

**Channel setup lives in `.setup()`** — the local server and tunnel must be ready before any step runs. Setup failures skip all steps and go straight to teardown.

**Wait via Promise, not polling** — the local server resolves a Promise when it receives the hook. This is faster and more precise than polling. Use `pollUntil` only if you're checking a delivery log API instead of receiving directly.

**Teardown always runs** — delete the webhook endpoint and close the server/tunnel even on failure. Leaked endpoints accumulate and can trigger rate limits or phantom deliveries.

**Signature verification is non-optional** — if the service signs webhooks (Stripe, GitHub, Slack all do), verify the signature in your test. A test that checks payload but skips signature verification is incomplete.

## Without a tunnel (delivery log approach)

If the service exposes a delivery history API, you don't need a tunnel at all:

```typescript
export const webhookDelivery = test("webhook-delivery-via-log")
  .meta({ tags: ["webhook"] })

  .step("trigger", async (ctx) => {
    const order = await api.post("orders", { json: { item: "test" } }).json<{ id: string }>();
    return { orderId: order.id };
  })

  .step("verify delivery", async ({ pollUntil, expect, log }, { orderId }) => {
    // Poll the delivery log instead of receiving the hook
    const delivery = await pollUntil({ timeoutMs: 30000, intervalMs: 2000 }, async () => {
      const logs = await api.get(`webhooks/deliveries?event=order.created`).json<any[]>();
      return logs.find((d) => d.payload?.orderId === orderId);
    });

    expect(delivery.status).toBe("delivered");
    expect(delivery.responseCode).toBe(200);
    log(`Delivery confirmed: ${delivery.id}`);
  });
```

Simpler, no infrastructure dependencies. But only works when the service provides delivery logs.

## Environment setup

```bash
# .env
SMEE_URL=${SMEE_URL}

# Get a channel: visit https://smee.io/new, copy the URL
# Export in your shell: export SMEE_URL=https://smee.io/your-channel
```

The `SMEE_URL` uses `${SMEE_URL}` host variable passthrough — see [multi-env.md](multi-env.md). The agent should ask the user to create a smee channel if one doesn't exist.

## Agent behavior

- Ask the user: "Does your service provide a webhook delivery log API?" If yes, prefer the delivery log approach (no tunnel needed).
- If a tunnel is needed, suggest smee.io as the default. Ask: "Do you have a smee.io channel URL, or should I help you set one up?"
- Always include signature verification if the service supports it.
- Always clean up registered webhook endpoints in teardown.
- Webhook tests are inherently slower (network round-trip + delivery delay). Set reasonable timeouts.

## Reference

- Working example: [cookbook/explore/stripe/webhook.test.ts](https://github.com/glubean/cookbook/tree/main/explore/stripe/webhook.test.ts)
- Async waiting: [polling.md](polling.md)
- Environment variables: [multi-env.md](multi-env.md)
