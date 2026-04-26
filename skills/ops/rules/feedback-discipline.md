# Rule — Feedback Discipline

Same shape as fe/be's. OPS-specific patterns:

## When to write feedback

- **Platform mismatch**: spec prescribes a platform that doesn't fit the workload
- **IaC conflict**: spec assumes infrastructure that isn't there or conflicts with current state
- **Irreversible change request**: spec implies a destructive change with no migration path
- **Cost envelope issue**: spec implies infra spend dramatically beyond reasonable
- **Code dependency**: spec needs code-side capability that doesn't exist yet
- **Compliance / security violation**: spec violates policy or regulation
- **Code-conflict / missing-AC / over-prescription**: same as fe/be

Don't write feedback for:

- "I prefer a different platform" with no concrete reason
- "This will be hard to operate" — that's not feedback, that's work
- Aesthetic disagreements about config style

## Strong vs weak feedback

Same as fe/be. Strong feedback cites evidence (existing IaC file:line, platform doc URL, cost calculation, compliance regulation). Weak is vague.

## Tone

Same as fe/be. Neutral, professional, concrete.

## OPS-specific traps

### Trap: cost feedback without numbers

```
WEAK:
> This will be expensive on Cloud Run.

STRONG:
> Cost estimate for this workload on Cloud Run: ~$2400/mo at the spec's
> stated 1000 concurrent connections. Same workload on GKE small node
> (n1-standard-2): ~$120/mo + cluster overhead. Difference is 20x.
```

### Trap: platform feedback as preference

```
WEAK:
> I'd rather use Cloudflare Workers for this; we have more experience.

STRONG:
> The spec asks for Cloud Run. Concerns:
> 1. Service involves long-lived ws connections (>60min); Cloud Run has 60min limit
> 2. Per platform-selection.md Q4, stateful/long-lived workloads belong on K8s
> Recommend GKE deployment instead. Workers also viable but introduces a new
> platform to our infra (we don't currently use Workers); may not be worth it.
```

The first reads like preference; the second reads like analysis.

### Trap: refactor-as-feedback

You see the existing IaC could be cleaner. Don't bundle that into feedback for THIS task:

```
DON'T:
> Concerns about this task's spec, plus while we're at it, the entire
> Terraform module structure should be reorganised.

DO:
> Concerns about this task's spec: [details]
> 
> Separately (not blocking this task): I noticed the module could be
> reorganised; willing to file as a follow-up if relevant.
```

Bundling makes arch-feedback's accept/counter decision harder.

### Trap: feedback that's actually scope expansion

Spec says "deploy cancel-svc"; you find that cancel-svc has no observability and want to add it before deploying. Two paths:

- **If observability is genuinely required for ship**: scope expansion via Mode C: "this service can't ship to prod without observability per `observability-default.md`; need a sibling task or scope expansion of this task"
- **If it's "would be nice"**: do this task as scoped; file follow-up

Don't quietly expand scope by adding observability mid-implement; flag it.

## Round limit awareness

Same as fe/be. 2 rounds max; round 3+ escalates to arch-judgment automatically.

## Anti-patterns (OPS-specific)

- **Feedback as platform preference advocacy** — the framework exists to depersonalise these
- **Feedback that just complains** — must have options + preference
- **Feedback during an active incident** — wait until the incident's resolved; don't muddy investigation with spec discussion
- **Feedback as a way to delay shipping** — if the spec genuinely works (just is harder than you'd like), implement it

## After feedback returns

Same as fe/be: read new state, start fresh from `workflow/implement.md` Phase 1.
