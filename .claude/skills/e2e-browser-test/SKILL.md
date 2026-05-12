---
name: e2e-browser-test
description: |
  Default sub-skill of `blackbox-validator`. Real browser automation against
  the sandbox-deployed app: navigate to URLs, click buttons, fill forms,
  assert visible state, take screenshots as evidence.

  Use when an AC mentions UI, pages, user flow, or browser-specific behaviour
  (e.g., "works on iOS Safari"). For API-only ACs, use `api-contract-test`
  instead.

  Implementation: invokes Playwright via Node OR a browser-control tool (e.g.,
  the `browse` skill if available). Tests one AC per "scenario block" inside
  the run, with screenshots between steps for audit.
allowed-tools:
  - Bash
  - Read
agent-class: BlackBoxValidator (sub-skill)
chained-from: blackbox-validator
---

# e2e-browser-test

You run real browser scenarios against the sandbox app to verify ACs that involve user-visible behaviour. Your job: one AC = one scenario = one PASS/FAIL with concrete evidence.

You are **not** running comprehensive QA. You verify the **specific AC** the orchestrator handed you. If you notice unrelated bugs during the scenario, log them as `note`-severity findings — don't expand scope.

---

## Inputs (passed by orchestrator)

- The specific AC to verify (text + ID)
- Sandbox URL (e.g., `https://wp4-xxx.vercel.app`)
- Optional: user agent / viewport per AC (e.g., AC mentions iOS Safari → use that user agent)
- Optional: seed data references (existing accounts / fixtures pre-loaded into sandbox)

---

## Browser automation: pick the right tool

The actual driver depends on what's available in the runtime. Order of preference:

1. **Real browser via Playwright** — `npx playwright test` or direct `playwright` Node API. Best fidelity; supports screenshots, user agents, viewports, mobile emulation.
2. **`browse` skill** (if installed; from gstack ecosystem) — wraps Playwright with a friendlier CLI.
3. **`curl` + HTML parse + manual flow simulation** — fallback when Playwright unavailable. Works for static-render pages; degrades for JS-heavy SPAs.

If the WP's AC says "iOS Safari" or "mobile" specifically, **Playwright is mandatory** — degraded curl can't honour user-agent / mobile viewport realistically. If Playwright is unavailable, return verdict `error` with explanation; the orchestrator will route to Arbiter.

---

## Scenario shape (one per AC)

Each scenario is structured:

```
SCENARIO: AC#2 — Two-or-more households can co-build lists

SETUP
  - browser: iPhone 14 viewport (390×844)
  - user agent: iOS Safari
  - sandbox URL: https://wp4-xxx.vercel.app

STEPS
  1. visit /signin
     → screenshot: 01-signin.png
  2. enter email "user1@test.dev" + click magic-link → simulate click via API
  3. session cookie set; visit /household/new
     → screenshot: 02-new-household.png
  4. fill name "Test household" + click Create
     → assert: redirect to /household/<id>
     → screenshot: 03-household-created.png
  5. click "Invite roommate" → enter "user2@test.dev"
     → assert: invite token shown
     → screenshot: 04-invite.png
  6. (switch to second browser session)
  7. user2 accepts invite via magic link
     → screenshot: 05-user2-joined.png
  8. (switch back to user1) — visit /list/new → create list "Groceries"
     → screenshot: 06-list-created.png
  9. (switch to user2) — visit /list → assert: "Groceries" visible
     → screenshot: 07-user2-sees-list.png ← KEY ASSERTION

VERDICT
  pass | fail
  evidence: [01..07].png
  if fail:
    expected: user2 sees "Groceries" in their list view
    observed: user2 sees empty list view (no items)
    classification: implementation-defect (the AC is clear)
```

---

## Process

### 1. Read AC, identify the user-observable surface

Translate the AC into:
- **Initial state** (what's pre-set up)
- **Actor(s)** (one or more browser sessions)
- **Sequence of actions**
- **Observable assertion** (what's visible at the end)

If you can't translate the AC into this shape, the AC may be ambiguous → return verdict `fail` with `failure_classification: ac-ambiguity` + explanation.

### 2. Drive the browser

Pseudo-code:

```bash
# Use playwright via Node script, or browse skill if available
node -e '
const { chromium, devices } = require("playwright");
(async () => {
  const browser = await chromium.launch();
  const iPhone = devices["iPhone 14"];
  const context = await browser.newContext({ ...iPhone });
  const page = await context.newPage();

  await page.goto("https://wp4-xxx.vercel.app/signin");
  await page.screenshot({ path: "/tmp/01-signin.png" });
  await page.fill("input[name=email]", "user1@test.dev");
  await page.click("button[type=submit]");
  // ... continue scenario
  await browser.close();
})();
'
```

The exact tool incantation matters less than: take screenshots at each step; assert at the AC's observable point.

### 3. Capture evidence

For each step that informs the verdict:
- Save screenshot to `/tmp/<scenario-id>-step-NN.png`
- Capture relevant network responses (visible via Playwright's `page.on("response", ...)`)
- Capture console errors

### 4. Decide PASS / FAIL + classify

- **PASS**: the final assertion holds.
- **FAIL — implementation-defect**: AC was verifiable, observed state ≠ expected, the cause is a code change (not the AC's fault).
- **FAIL — ac-ambiguity**: the AC itself is unclear — multiple interpretations exist, and none observable from the user's POV.
- **error**: scenario couldn't run (Playwright crashed, sandbox unreachable, etc.) — orchestrator escalates to Arbiter.

### 5. Return structured result

```json
{
  "ac_id": "AC#2",
  "method": "e2e-browser-test",
  "verdict": "pass" | "fail" | "error",
  "evidence": [
    {"type": "screenshot", "path": "/tmp/ac2-01-signin.png"},
    {"type": "screenshot", "path": "/tmp/ac2-07-user2-sees-list.png"},
    {"type": "network", "summary": "GET /api/list as user2 → 200 + empty array"}
  ],
  "failure_classification": null | "implementation-defect" | "ac-ambiguity",
  "message": "Expected user2 to see 'Groceries' on /list. Observed: empty array. Network: GET /api/list returns []. Inferred: list is scoped to user_id, not household_id (visible from API but root cause is code-side; not AC fault).",
  "scenario_steps": [ "...optional human-readable step trace..." ]
}
```

---

## Decision rules

- **One scenario, one AC.** Don't combine multiple ACs into one scenario; if the AC list is intertwined, request separate runs.
- **Screenshot the key assertion.** Even if scenario passes, capture the final screenshot — it's evidence for the audit.
- **Network errors during the scenario** that are not the AC's failure point → log as console messages in `evidence`, but don't fail the AC unless the failure manifests at the assertion point.
- **Console errors**: collect them. If a console error directly causes the failure (e.g., uncaught exception breaks the flow), report it as the root cause in `message`. If errors are unrelated noise (third-party widget errors, analytics 404), mention but don't make them the verdict driver.
- **No retries inside the scenario.** If the assertion fails, return FAIL. The orchestrator + Dispatch handles retries at the WP level (`retry:black-box:N`).

---

## Examples of AC types this skill verifies well

- "Mobile UI passes iOS Safari and Android Chrome" → two scenarios, one per user agent
- "User can create a household and invite a roommate" → multi-actor scenario
- "Checkout completion event fires once per successful checkout" → scenario + network assertion
- "Form shows validation error for invalid email" → simple form scenario

## AC types this skill does NOT verify (route elsewhere)

- "API returns 401 for unauthenticated POST" → `api-contract-test` (no UI involved)
- "Module X uses pattern Y internally" → not observable from black-box (likely AC-ambiguity)
- "p95 < 200ms" → `api-contract-test` or `stress-test` under WhiteBox (measured, not browser-y)
- "Database has correct schema" → `api-contract-test` or a contract check (not user-visible)

---

## Access boundaries (per ADR-0009)

| Resource | Access |
|---|---|
| Sandbox URL via HTTP/browser | ✅ |
| Screenshots / network logs to `/tmp/` | ✅ |
| Spec AC text (only the AC under test) | ✅ |
| Code | ❌ |
| `.rlm/facts/*` | ❌ |
| Discord | ❌ |
| RLM write | ❌ |

---

## What this skill does NOT do

- Does not read source code
- Does not modify code
- Does not test multiple ACs in one scenario
- Does not run full regression QA — only the specific AC handed in
- Does not aggregate findings into a verdict comment — returns per-AC result to `blackbox-validator`
