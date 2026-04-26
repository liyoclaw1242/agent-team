# Workflow — Feedback (Mode C)

OPS Mode C is rarer than fe/be's because OPS doesn't usually consume specs in the same shape. But it does come up.

## Common triggers

- **Platform mismatch**: spec says "deploy to Cloud Run" but the service has stateful streaming requirements that Cloud Run doesn't support
- **IaC conflict**: spec assumes a resource shape (region, naming, IAM) that conflicts with existing infrastructure
- **Reversibility impossible**: spec asks for a destructive change with no migration path
- **Cost outside expected envelope**: spec implies infra spend dramatically beyond what would be expected
- **Code-level dependency**: spec assumes capability (e.g., graceful shutdown handling) that the code doesn't have yet
- **Compliance / security violation**: spec would expose a service publicly that should be private, or store data outside the allowed region

## Confirm before posting

Same as fe/be — reality-check your concern:

- For platform mismatch: confirm by reading the platform's docs or checking existing patterns in the repo
- For IaC conflict: read existing IaC; check if other PRs are in flight
- For reversibility: think through the rollback step-by-step; if you can't construct it, it's real
- For cost: estimate actual spend; if dramatically off, you have a case

## Format

Header is exactly `## Technical Feedback from ops`:

```markdown
## Technical Feedback from ops

### Concern category
{platform-mismatch | iac-conflict | irreversible-change | cost-envelope |
 code-dependency | compliance-violation | code-conflict | missing-AC |
 over-prescription | wrong-outcome}

### What the spec says
{quote the specific text}

### What the infra / codebase / cost reality shows
{evidence: existing IaC, platform docs, cost estimate, compliance constraint}

### Options I see
1. {option A}
2. ...

### My preference
{which option, with rationale}

### Drift noticed (optional)
{IaC drift, undocumented manual changes, etc.}
```

## Post and route

```bash
bash actions/feedback.sh \
  --issue $ISSUE_N \
  --feedback-file /tmp/feedback-$ISSUE_N.md
```

Same flow: post, route to `agent:arch`, dispatcher → arch-feedback.

## OPS-specific examples

### Example 1: platform mismatch

```markdown
## Technical Feedback from ops

### Concern category
platform-mismatch

### What the spec says
"Deploy the websocket gateway to Cloud Run for autoscaling"

### What the infra / platform reality shows
- Cloud Run has request-bound execution model: instances are billed per
  request, scaled down between requests
- Long-lived websocket connections don't fit this model: the connection
  ends up holding an instance for hours
- Cost estimate: with 1000 concurrent ws connections at typical durations,
  ~$2400/mo on Cloud Run vs ~$120/mo on a small GKE deployment
- Cloud Run has a 60-min connection limit anyway

### Options I see
1. GKE deployment (better fit for long-lived connections)
2. Cloud Run with reconnect logic in clients (every ≤60min)
3. Cloud Run with a connection-pooling layer in front (complex)

### My preference
Option 1. GKE is the standard answer for stateful or long-lived workloads
in our infra; Cloud Run shines for stateless burst traffic.

### Drift noticed
None.
```

### Example 2: irreversible change

```markdown
## Technical Feedback from ops

### Concern category
irreversible-change

### What the spec says
"Drop the legacy_metrics tables from production database"

### What the infra reality shows
- 2.4TB of historical data, ~3 years of metrics
- Drop is irreversible without restore from backup
- Backup retention is 30 days; older data not recoverable
- Some external compliance reports query this data quarterly

### Options I see
1. Don't drop — archive to GCS and keep DB tables for compliance access
2. Drop with extended backup (snapshot before drop, retain indefinitely)
3. Migrate compliance queries to alternative data source first; then drop
4. Multi-step: archive → wait 6 months for queries to settle → drop

### My preference
Option 4. Archive cost is small relative to the risk of losing data needed
for compliance. The 6-month wait window is cheap insurance.

### Drift noticed
None directly relevant; flagging that compliance team should be looped in
for any path here.
```

### Example 3: code dependency

```markdown
## Technical Feedback from ops

### Concern category
code-dependency

### What the spec says
"Configure the cancel-svc deployment with rolling update strategy
(maxUnavailable=0)"

### What the codebase shows
- cancel-svc handles SIGTERM but does not gracefully drain in-flight
  cancellation requests
- Currently SIGTERM → process exits within 100ms regardless of in-flight
- maxUnavailable=0 with rolling update means new pods come up before old
  pods drain — but old pods still drop in-flight requests on shutdown
- Result: cancellations in flight during deploy will fail

### Options I see
1. Add graceful shutdown to cancel-svc (BE task) before changing rollout strategy
2. Configure terminationGracePeriodSeconds=30 (k8s waits before SIGKILL);
   only partial — code still doesn't drain
3. Use a sidecar / init pattern to drain (overkill)

### My preference
Option 1. File a BE task to add graceful shutdown; this OPS task waits on it.

### Drift noticed
None.
```

This is OPS noticing a code-side dependency that arch-shape didn't account for. arch-feedback should accept (with deps marker) or re-shape.

## Anti-patterns

- **Over-engineering as feedback** — "we should add a service mesh first" when the task is simple. If the spec works with simpler infra, do that; save the mesh for an architecture intake.
- **Cost-envelope feedback without estimation** — "this looks expensive" isn't feedback. Either you have an estimate (cite it) or you don't.
- **Compliance feedback without citation** — "I think this violates compliance" — name the regulation / policy. Otherwise it's an opinion.
- **Feedback that's just preference for a different platform** — "I'd rather use Cloudflare" with no concrete reason. Stick to spec unless platform genuinely doesn't fit.

## After feedback returns

Same as fe/be: read the new issue state, start fresh from `workflow/implement.md` Phase 1.
