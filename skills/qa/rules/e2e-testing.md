# Rule: E2E / UI Testing (Chrome MCP)

## Tool: Chrome MCP

Use Chrome MCP to operate a real browser. This is for **verification**, not for writing persistent test files.

## Approach

1. Follow the test plan steps (U1, U2, ...) sequentially
2. For each step:
   - Perform the action via Chrome MCP
   - Wait for the page to settle (navigation, loading, animations)
   - Verify the expected outcome by reading page content
   - Take a screenshot as evidence

## What to Verify

| Check | How |
|-------|-----|
| Page loads | Navigate, confirm no error screen |
| Content correct | Read text content of key elements |
| Interaction works | Click/type, verify state change |
| Navigation works | Click link/button, verify URL changed |
| Form validation | Submit invalid data, verify error messages |
| Responsive layout | Resize viewport, verify no broken layout |
| Error states | Trigger errors (bad URL, expired session), verify graceful handling |

## What NOT to Do

- Do NOT write Playwright test files unless the spec specifically asks for persistent E2E tests
- Do NOT test internal implementation details (Redux state, component props)
- Do NOT test third-party widgets in depth (date pickers, rich editors) — just verify they render

## Screenshot Evidence

Take screenshots at these moments:
- Before performing the action (initial state)
- After performing the action (result state)
- On failure (capture the actual broken state)

Name screenshots: `{step}-{before|after}.png` (e.g., `U1-after.png`)

## Selectors

Prefer human-readable selectors:
- `button:has-text("Submit")` over `#submit-btn`
- `input[name="email"]` over `.form-field:nth-child(2) input`
- `[role="dialog"]` over `.modal-overlay > .modal-content`
