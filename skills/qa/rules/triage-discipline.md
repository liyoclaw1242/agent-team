# Rule — Triage Discipline

The `triage:` field on a FAIL verdict tells `pre-triage.sh` which role to route the failed issue to. Picking it correctly matters; the wrong triage wastes a round-trip.

## Choosing triage

Pick the role whose change is needed to fix the FAIL finding.

| Finding type | Triage to |
|--------------|-----------|
| UI bug, frontend logic, missing UI state | `fe` |
| API misbehaviour, wrong status code, server logic | `be` |
| Data-shape mismatch with contract | `be` (BE owns contracts; if wrong shape, BE fixes) |
| Visual / layout / spacing wrong | `fe` (if implementation diverged from spec) or escalate to design (if spec itself is wrong) |
| Deployment / config / secret / DNS issue | `ops` |
| Performance issue traced to backend | `be` |
| Performance issue traced to frontend | `fe` |
| Missing / weak tests | the role whose tests are missing (usually the implementer) |
| Documentation gap | usually the implementer of the documented thing |

## When the failure is multi-role

You found two issues, each pointing at a different role.

### Sub-case 1: one is the trigger, the other is downstream

Example: FE handles 500 errors poorly because BE returns 500 instead of 400 on bad input. BE is the trigger; FE is downstream.

Triage to BE. The verdict's evidence section makes the chain clear:

```markdown
- AC #4: error handling — ✗
  Evidence:
  - BE returns 500 for invalid request body (should be 400 per spec)
  - Because of the 500, FE shows generic "something went wrong" instead of the field-level error
  - The FE handling for 4xx is correct; the BE response shape is the issue
  Triage: be
```

Once BE is fixed, the FE behaviour will likely be correct. If after BE's fix the FE still fails, that's a new FAIL round.

### Sub-case 2: independent failures

Example: Cancel button visual style is wrong AND cancellation API returns 500.

These are independent. Triage to one role with the most-blocking finding; mention the other in evidence:

```markdown
- AC #2: ... — ✗
  Evidence: API returns 500 instead of 200 on success
  
- AC #5: ... — ✗
  Evidence: button colour wrong (uses --color-blue instead of --color-danger per Design spec)

triage: be
```

The triage points at the most-blocking issue (API failure prevents the flow from working at all). FE's visual fix can land on the same PR or in a follow-up. If you have to pick one, pick the one without which the feature is unusable.

### Sub-case 3: ambiguous

Sometimes you can't tell which role's change is needed. The bug is in a shared module both roles touch, or the contract itself seems wrong.

Triage to the role you suspect; in the evidence be clear that you're uncertain:

```markdown
triage: be
Evidence: the contract says effectiveDate ISO8601 but BE returns Unix timestamp.
Could be that BE diverged from contract, OR the contract was wrong from the
start. arch-feedback may need to clarify.
```

If after one round-trip the issue still fails (because you triaged the wrong role), the next QA verdict can switch triage based on what was learned.

## When triage is "none"

`triage: none` is correct on PASS verdicts.

On FAIL, `triage: none` is **not** a valid choice. If you genuinely don't know who should fix it, the fail is unverifiable from a routing standpoint — escalate via Mode C feedback to arch-judgment.

## Don't triage to arch / debug / qa / design

The valid triage values are `fe`, `be`, `ops`, `design`, or `none`.

`arch` / `debug` / `qa` are arch-family or specialty roles; they don't take fix routing.

`design` is acceptable when:
- The implementation matches Design's spec but the spec itself is wrong
- A finding is a Design-system concern (token mismatch, missing state)

If the finding is "FE didn't follow Design's spec", triage to `fe` (it's an implementation gap, not a spec issue).

## Don't triage to escalate

`triage:` is for routing to fix. It's not for escalating up the chain.

If the finding deserves arch-level reconsideration (the AC was wrong, the parent's outcome doesn't match what was built, the contract has ambiguity), that's Mode C feedback territory or an arch-judgment escalation, not a `triage:` value.

## Subtle: when QA's expectation was wrong

Sometimes during verify, you realise YOUR understanding of the AC was wrong — the implementer is correct, your verdict would unfairly FAIL them.

The right move:
- Don't post the FAIL verdict
- Re-read AC, parent, sibling tasks
- If after re-read you genuinely think the implementation is correct, post PASS
- If you're still unsure, Mode C feedback to clarify the AC's intent

This protects you from posting bad verdicts that bounce back as obvious mistakes.

## Anti-patterns

- **Always triaging to FE** ("they fix easier") — biases the system unfairly
- **Triage roulette when uncertain** — picking randomly. If you're uncertain, say so in evidence; don't randomise.
- **Triaging to multiple roles** — `triage: fe, be` is not valid format. Pick one; mention the other in evidence.
- **Triaging to a role that didn't author the code** — if BE didn't touch this PR, you can't triage to BE for a bug in this PR. Look at git blame on the affected lines if unclear.
