# Browser Testing

## Why this pattern

**Problem:** you need to test a web UI (login form, dashboard rendering, data extraction) but raw Playwright has no integration with Glubean's assertion reporting, traces, or Cloud dashboard.
**Alternative:** use Playwright directly — but you lose automatic screenshots on failure, HTTP trace capture, structured assertion reporting, and Cloud result upload. You also need a separate test runner and reporter.
**This pattern:** `@glubean/browser` wraps Playwright with auto-tracing, screenshot capture, and Glubean assertion integration. Tests use the same `test()` / `expect()` / `configure()` API as HTTP tests, results appear in the same reports, and everything uploads to Cloud together.

> **Requires:** `npm install @glubean/browser`

## Setup (see also configure.md)

```typescript
// config/browser.ts
import { test, configure } from "@glubean/sdk";
import { browser } from "@glubean/browser";
import type { InstrumentedPage } from "@glubean/browser";

export const { chrome } = configure({
  plugins: {
    chrome: browser({
      launch: true,
      launchOptions: { headless: true },
    }),
  },
});

export const browserTest = test.extend({
  page: async (ctx, use: (instance: InstrumentedPage) => Promise<void>) => {
    const pg = await chrome.newPage(ctx);
    try { await use(pg); }
    finally { await pg.close(); }
  },
});
```

## Smoke test

```typescript
import { browserTest } from "../../config/browser.ts";

export const dashboardLoads = browserTest(
  { id: "dashboard-loads", name: "Dashboard renders", tags: ["e2e", "smoke"] },
  async ({ page, vars }) => {
    await page.goto(vars.require("APP_URL"));
    await page.expectVisible(".dashboard");
    await page.expectText("h1", "Dashboard");
  },
);
```

## Form + navigation

```typescript
export const loginFlow = browserTest(
  { id: "login-flow", name: "User can log in via form", tags: ["e2e", "auth"] },
  async ({ page }) => {
    await page.goto("https://the-internet.herokuapp.com/login");
    await page.type("#username", "tomsmith");
    await page.type("#password", "SuperSecretPassword!");
    await page.clickAndNavigate('button[type="submit"]');
    await page.expectURL("/secure");
    await page.expectText("#flash", /logged into a secure area/);
  },
);
```

## Data extraction

```typescript
export const extractTableData = browserTest(
  { id: "extract-table", name: "Extract data from table", tags: ["e2e"] },
  async ({ page, expect, log }) => {
    await page.goto("https://the-internet.herokuapp.com/tables");
    const rows = await page.evaluate(() => {
      const trs = document.querySelectorAll("#table1 tbody tr");
      return Array.from(trs).map((tr) => ({
        lastName: tr.querySelector("td:nth-child(1)")?.textContent?.trim(),
        firstName: tr.querySelector("td:nth-child(2)")?.textContent?.trim(),
        email: tr.querySelector("td:nth-child(3)")?.textContent?.trim(),
      }));
    });
    expect(rows.length).toBeGreaterThan(0);
    log(`Extracted ${rows.length} rows`, rows);
  },
);
```

## Dynamic elements (dropdown)

```typescript
export const dynamicDropdown = browserTest(
  { id: "dynamic-dropdown", name: "Select from dropdown", tags: ["e2e"] },
  async ({ page, expect }) => {
    await page.goto("https://the-internet.herokuapp.com/dropdown");
    await page.select("#dropdown", "2");
    const value = await page.inputValue("#dropdown");
    expect(value).toBe("2");
  },
);
```

## Page API quick reference

```typescript
// Navigation
await page.goto(url);

// Interaction
await page.click(selector);
await page.clickAndNavigate(selector);  // Click + wait for navigation
await page.type(selector, text);
await page.fill(selector, value);       // Clear + type
await page.select(selector, value);
await page.hover(selector);
await page.press("Enter");
await page.upload(selector, filePath);

// Assertions (soft-fail, auto-waiting)
await page.expectText(selector, text | regex);
await page.expectURL(path | regex);
await page.expectVisible(selector);
await page.expectHidden(selector);

// DOM queries
const text = await page.textContent(selector);
const html = await page.innerHTML(selector);
const value = await page.inputValue(selector);
const visible = await page.isVisible(selector);

// Evaluate JS in browser
const result = await page.evaluate(() => { ... });

// Screenshots
await page.screenshot();

// Wait
await page.waitForURL(url);

// Locator
await page.locator(selector).click();
await page.locator(selector).fill(text);
```
