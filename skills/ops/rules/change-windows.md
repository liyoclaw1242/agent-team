# Rule — Change Windows

High-risk changes happen during defined windows. Low-risk changes are continuous. The classification matters because timing failures (Friday afternoon production deploy gone wrong) is a leading cause of incidents.

## Risk classification

Each OPS change falls into one of three risk levels.

### Low risk — apply continuously

Examples:
- Replica count changes (scale up)
- HPA threshold tuning
- Adding a non-critical metric / log line
- Documentation / runbook updates
- New non-routed endpoint deploy (released behind a flag, off by default)
- CI workflow improvements

These can apply any time, including business hours and Fridays. They're recoverable in <5 min if they go wrong, and they typically don't.

### Medium risk — apply during business hours

Examples:
- Standard service deploys (new code release; not behind a flag)
- IaC changes that touch a single non-critical service
- Adding a new alert rule
- Container image base updates
- Adding/removing a non-database resource

Business hours = enough engineers around to respond if it goes wrong. Most teams: 10am–4pm in the team's primary timezone, Mon–Thu. **Avoid Fridays** — if it breaks Friday evening, the team is stretched over the weekend.

### High risk — scheduled change windows

Examples:
- Database schema migrations (especially destructive)
- DNS changes
- IAM / security policy changes
- Network topology changes
- Multi-service simultaneous deploys
- Cross-region resource changes
- Anything affecting payment processing, auth, or compliance-critical data

Scheduled windows are explicit, announced ahead of time, and during low-traffic periods. Typical window: weekday morning (10am-12pm local) when traffic is low and engineers are starting their day.

## How to classify a given change

Apply this checklist to your change:

| Question | If yes, escalate by one level |
|----------|-------------------------------|
| Does it touch DNS, IAM, or networking? | yes — probably High risk |
| Does it modify or destroy data? | yes |
| Does it span multiple services in one apply? | yes |
| Is rollback time >5 minutes? | yes |
| Are downstream services dependent on it without circuit breaker? | yes |
| Is this the first deploy of a new service in production? | yes |
| Does it require a corresponding code-side change to land first? | yes |

Two yeses → escalate one level. Three yeses → escalate two levels.

## What "scheduled change window" requires

For high-risk changes:

1. **Announcement**: post in the team's announcements channel ≥24h ahead with:
   - What the change is
   - When it's planned
   - Expected duration
   - Rollback plan
   - Who is on standby

2. **Apply with a second person**: pair-apply for high-risk; the second person watches metrics, ready to call abort

3. **Defined success criteria**: pre-stated metrics that, if they breach, trigger immediate rollback (e.g., "error rate stays under 0.5% for 30 minutes after apply")

4. **Window discipline**: if the window passes and the change isn't ready, **don't ship anyway**. Reschedule.

## Windows are not just about technical risk

Some windows are about availability of expertise, not technical risk:

- Don't deploy when a key person is on vacation if their expertise is needed for rollback
- Don't deploy during an active incident on a related service
- Don't deploy minutes before a known traffic spike (campaign launch, holiday)

These signals are external to the change itself. OPS should know enough about the team's calendar and service traffic patterns to factor them in.

## Emergency exception

Sometimes high-risk changes must happen NOW (Sev 1 with no other mitigation, security patch needed immediately). The rule allows exceptions but requires:

- Explicit human approval (not just OPS unilateral)
- All else equal, prefer less-destructive change to a fuller fix
- Document the exception in the issue: why it couldn't wait, who approved
- Schedule a postmortem on the change's risk class — was the underlying issue preventable?

The exception is for genuinely time-critical work, not for "I want to ship today".

## How this rule shows up in the workflow

In `workflow/implement.md` Phase 6's self-test record:

```markdown
## Change-window awareness

Risk class: medium (single-service deploy of new code release)
Plan: apply during business hours, Tue-Thu morning. Avoiding Friday.
```

For high-risk:

```markdown
## Change-window awareness

Risk class: high (DNS change, propagation up to 24h, irreversible during propagation)
Window: scheduled Tue 10:00 UTC, announced in #announcements (link)
Standby: @teammate
Success criteria: DNS resolves correctly via dig in 5 distinct geographies within 60min;
  no spike in DNS-related error logs above baseline for 4h post-apply
```

`actions/deliver.sh` does NOT mechanically enforce this — risk classification is judgment-based. But the self-test record's presence of a Change-window section is checked.

## When a junior OPS misclassifies

If you're uncertain whether something is medium vs high risk, default to high. The cost of a high-risk-classified low-risk change is "we waited until 10am Tuesday to apply it" — small. The cost of misclassifying high as medium and shipping Friday afternoon is unbounded.

## Anti-patterns

- **Friday afternoon "one quick deploy"** — the most reliable way to ruin a weekend
- **"It's only one config change"** — config changes can be high risk (auth, networking, secrets)
- **Window discipline that's enforced for code but not config** — same risk applies; same rules
- **Stacking multiple medium-risk changes into one window** — if any one fails, you have to disentangle multiple. One change per window for medium+.
- **Treating change windows as optional under time pressure** — pressure is exactly when discipline matters most
