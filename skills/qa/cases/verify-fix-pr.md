# Case — Verify a Fix PR (filed by debug)

A bug was investigated by debug; debug filed a fix issue (`source:arch`, `agent:{role}`); implementer addressed it; PR is up. QA's verify mode now confirms the fix actually works.

This case differs from feature verification in two ways:
1. The "AC" is essentially "the bug from the original report no longer reproduces"
2. The original bug issue is still open and waiting to close once this fix lands

## Worked example

- Original bug: #BUG_N (filed by user; investigated by debug; root-cause report posted)
- Fix issue: #FIX_N (filed by debug via `file-fix.sh`; agent:fe; tagged `<!-- bug-of: #BUG_N -->`)
- Fix PR: #501 (FE submitted, references `Refs: #FIX_N`)
- QA verify task: this is what you're picking up

## Phase 1 — Read

```bash
# The fix issue body (your AC come from here)
gh issue view $FIX_N

# The original bug — read the root-cause report
gh issue view $BUG_N

# The PR
gh pr view 501

# The debug investigation (in $BUG_N's comments)
gh issue view $BUG_N --json comments --jq '.comments[].body' | grep -A 50 "Root cause report"
```

What you read:
- Bug report from a user: "checkout page crashes for users with no expiration date on their payment method"
- Debug's root-cause report: "PaymentSummary.tsx passes nullable date to formatExpiry which doesn't null-check"
- Fix issue's AC:
  - The repro from #BUG_N no longer crashes
  - Display shows "—" or "No expiry" when expiration is null
  - A regression test exists covering this path
- Implementer's PR: adds null check, adds test, adds "—" display string

## Phase 2 — Run validators

Same as feature verification. PR's role validators must pass on HEAD.

## Phase 3 — Verify the fix actually fixes the bug

This phase is the heart of fix verification. Walk:

### Step 1: reproduce the bug on the PR's preview

Before the fix landed, the bug would reproduce. Try the same repro on the PR's preview:

```
- Logged in as test user with PM #99 (the no-expiry user from the bug)
- Visited /checkout
- Observed: page renders correctly. PaymentSummary shows "Card ending 4242 — No expiry"
- No console errors
```

The bug no longer reproduces. ✓

### Step 2: verify the regression test exists

```bash
grep -r "expirationDate.*null\|formatExpiry.*null" tests/ --include="*.tsx"
# Found: tests/PaymentSummary.test.tsx — TestPaymentSummary_NullExpiry_DisplaysFallback
```

Test exists, passes in CI. ✓

### Step 3: verify the AC from the fix issue are met

Per the fix issue's AC list:
- ✓ Repro doesn't reproduce (verified above)
- ✓ Null expiration shows "—" or similar (verified visually)
- ✓ Regression test exists (verified above)
- ✓ No regression in non-null expiration display (TestPaymentSummary_NormalExpiry still passes)

### Step 4: edge cases the original investigation called out

The debug report's "Why this happens" mentioned the broader concern: other places that format dates might have the same vulnerability.

Check whether the fix is local-only or addresses the broader concern:

```bash
grep -r "\.getMonth()\|\.getFullYear()" src/ --include="*.ts" --include="*.tsx"
# Found 2 other call sites:
# - src/billing/SubscriptionCard.tsx:88 (uses paymentMethod.expirationDate)
# - src/admin/CardList.tsx:42 (uses card.expiresAt)
```

If the PR only fixed PaymentSummary.tsx, the SubscriptionCard and CardList have the same bug class.

This is a finding worth surfacing, even if AC don't strictly require it:

```markdown
Notes:
- The fix is local to PaymentSummary.tsx. Two adjacent files (SubscriptionCard.tsx:88, CardList.tsx:42) have the same null-date-deref pattern. The original debug report flagged this as worth considering. The current fix passes the AC but doesn't address those.
- Recommend: filing a follow-up to fix the other two sites (similar shape, mechanical fix).
```

This is part of QA's role: surfacing observations that the AC didn't cover but a thoughtful reviewer would flag.

## Phase 4 — Verdict

If the AC are met:

```markdown
## QA Verdict: PASS

- AC #1: Repro from #BUG_N no longer crashes — ✓
  Evidence: ran the repro on PR preview; page renders correctly with "No expiry" displayed
- AC #2: Null expiration shows "—" or fallback — ✓
  Evidence: verified visually; matches fallback string
- AC #3: Regression test added — ✓
  Evidence: TestPaymentSummary_NullExpiry_DisplaysFallback in tests/; passes in CI
- AC #4: No regression in normal flow — ✓
  Evidence: TestPaymentSummary_NormalExpiry still passes; manual check with normal payment method works

triage: none

Verified-on: abc1234

Notes:
- The fix is local to PaymentSummary.tsx. Two adjacent files (SubscriptionCard.tsx, CardList.tsx) appear to have the same null-deref pattern per the original debug report. Filing a follow-up: see #200.
```

The PASS lets the PR merge. When merged:
- The fix issue (`#FIX_N`) closes (PR's `Refs:` triggers it)
- `scan-complete-requests.sh` notices the bug issue's deps (`<!-- deps: #FIX_N -->`) is now closed; closes `#BUG_N`

So both issues close from this single PASS verdict.

## Variant: fix doesn't actually fix the bug

You ran the repro on the PR preview and the bug still happens.

This is a FAIL with a specific finding:

```markdown
## QA Verdict: FAIL

- AC #1: Repro from #BUG_N no longer crashes — ✗
  Evidence: re-ran the original repro on PR preview deploy; page still crashes with same console error.
  The PR adds a null check at PaymentSummary.tsx:88 but the actual crash trace shows
  the failure is in formatExpiry itself (dateFormat.ts:23), which still calls .getMonth() unconditionally.
  The fix is in the wrong layer.

triage: fe
```

The fix is at the call site; the bug is in the called function. The implementer needs to either fix `formatExpiry` or the null check needs to actually prevent the call.

## Variant: fix introduces a different bug

You verify the original repro is gone. But while clicking around you notice that **non-null** expiration display has been broken (the "—" fallback string is now shown for everyone).

This is a regression, also FAIL:

```markdown
## QA Verdict: FAIL

- AC #1: Repro from #BUG_N no longer crashes — ✓
- AC #2: Null expiration shows "—" — ✓ (works, but...)
- AC #4: No regression in normal flow — ✗
  Evidence: with a normal expiration date (12/2027), the display now shows "—" instead of "12/2027".
  The null check appears to always evaluate truthy due to a typo:
  `paymentMethod.expirationDate ? "—" : formatExpiry(...)` (the ternary is inverted)

triage: fe
```

Mechanical fix; routes back; round 2 should pass.

## Anti-patterns

- **Skipping the original repro** — verifying the PR's tests pass without re-running the bug's specific repro misses regressions of the original symptom. ALWAYS re-run the original repro on the fix PR.
- **Treating a debug-filed fix issue like a feature task** — the AC structure is different; the link to the original bug matters more than feature-AC walks.
- **Closing the bug issue yourself** — you don't. PASS verdict + PR merge → bug closes via `scan-complete-requests.sh`. QA doesn't manually close bugs.
- **Ignoring the "broader concern" callouts in the debug report** — these are signals from debug's investigation. Even if AC don't strictly require them, surface them in Notes:.
