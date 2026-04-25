# Rule — Severity Handling

Each audit finding has a severity tag. Fix tasks preserve this — both because urgency communicates priority and because severity affects how the fix is reviewed and tested.

## Severity scale

QA-audit and Design-audit templates use slightly different scales:

### QA-audit

| Tag | Meaning |
|-----|---------|
| Sev 1 | Production down, data loss, security breach |
| Sev 2 | Major feature broken, no workaround |
| Sev 3 | Bug with workaround |
| Sev 4 | Cosmetic / minor |

### Design-audit

| Tag | Meaning |
|-----|---------|
| Critical | Accessibility violation, brand violation, broken pattern |
| Major | Inconsistency that confuses users or violates design system |
| Minor | Polish, edge alignment, copy refinements |

## Mapping to fix tasks

When one fix groups multiple findings, the fix's severity is **the highest among them**. Reasoning: a fix that addresses both Sev 2 and Sev 4 needs to ship at Sev-2 priority.

Tag the fix with `<!-- severity: 2 -->` (numeric, mapped from word for design-audit findings: Critical=1, Major=2, Minor=3).

## How severity affects routing

`pre-triage.sh` doesn't use severity (it routes based on verdicts, not severity). But the implementing role and QA may use it:

- Sev 1 fixes typically go to the front of the role's poll queue
- Sev 4 / Minor fixes are often deferrable; the implementing role may batch them
- QA's verification depth scales with severity (Sev 1 fixes need rollback testing; Sev 4 may need only a smoke test)

These are role-side decisions, not arch-audit's. arch-audit just records the severity faithfully.

## Don't downgrade

Resist the urge to downgrade severity to make the fix look smaller. If the auditor said Sev 2, the fix is Sev 2. If you disagree with the assessment, comment on the audit issue, route back to the auditor for re-rating.

## Don't upgrade

Don't pump severity to get attention. If everything is Sev 1, nothing is.

## When the audit didn't tag severity

The template requires it; if it's missing, the audit is malformed. Comment, route back to the auditor:

```markdown
This audit is missing severity tags on findings 3, 7, 11. arch-audit
needs these to set fix priority correctly. Please update and the audit
will pick up again.
```

Then route the audit back: `route.sh $N {original-source} --reason "missing severity tags"`.

Don't guess.
