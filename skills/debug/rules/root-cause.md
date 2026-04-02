# Rule: Root Cause Determination

## The Test

**Can you explain the root cause in one paragraph without "might be", "probably", or "could be"?**

If not, you don't have the root cause yet. Go back to observing.

## What Counts as Root Cause

Root cause is the **first wrong thing** in the causal chain — the thing that, if fixed, prevents the entire failure cascade.

| Level | Example | Is root cause? |
|-------|---------|----------------|
| Symptom | "Users see 500 error" | No |
| Proximate cause | "NULL pointer in getTotal()" | No |
| Root cause | "Migration 042 added NOT NULL column without default" | Yes |

## Required Evidence

Every diagnosis must include:

1. **Trace ID** — at least one trace showing the failure
2. **File:line** — specific code location involved
3. **Timeline** — when the bug was introduced (git commit or deploy)
4. **Reproduction** — steps to trigger, or explanation of why not reproducible

## Anti-patterns

- **"The code looks wrong"** — without observability evidence, this is speculation
- **"It works on my machine"** — check environment differences via config/env comparison
- **"The fix is obvious"** — your job is to diagnose, not to fix. Even if the fix is one line, document the root cause fully
- **"Multiple possible causes"** — narrow down. If you truly have two candidates, design a test to distinguish them
- **Premature fix** — never commit a fix during investigation. Diagnose first, dispatch second. The Iron Law applies
