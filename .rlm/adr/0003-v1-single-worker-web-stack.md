# v1 ships with a single Worker BC: web-stack

The initial vision included Worker specialists for web frontend, server backend, DB migrations, UE5, Unity, and Blender. v1 ships with a **single generic Worker agent** (per [ADR-0016](./0016-worker-contract.md)) configured with a **`web-stack` skill profile** — frontend, server backend, DB migrations, and **deployment-as-code** (Vercel / Fly / Cloudflare config files, Dockerfiles, GitHub Actions deploy workflows). Future domains (UE5, Unity, Blender) are added as additional skill profiles, **not** new Worker agent classes.

## Why

Each of the originally proposed Worker domains has its own non-overlapping vocabulary, tooling, and validation strategy — a Blender artifact cannot be lint-checked; a UE5 build does not fit a five-minute validation pipeline; web "Component", Unity "Component", and Blender "Component" are three unrelated concepts. Shipping all of them as v1 would require a Worker *platform*, not a Worker. v1 ships when one skill profile works end-to-end; further profiles become a known expansion against the Worker contract (now [ADR-0016](./0016-worker-contract.md)).

## Consequences

- The Worker contract ([ADR-0016](./0016-worker-contract.md)) is skill-agnostic by design. Adding a new domain is a skill-set expansion, not a new agent class.
- Deferred Worker domains (UE5, Unity, Blender, dedicated DB-migration specialist, etc.) are scope, not capability gaps — listed as future skill profiles, not promised features.
- The 5-stage ValidationPipeline (per [ADR-0006](./0006-validation-pipeline.md)) currently assumes a runnable web artifact in stages 3–4. Future skill profiles will require stage-specific validation profiles when they are added.
