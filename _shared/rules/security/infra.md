# Security — Infrastructure (OPS)

Extends `base.md`. Build, deployment, runtime infrastructure security.

## Secrets management

- Secrets in CI come from the secret store, never inline in workflow YAML.
- GitHub Actions secrets: scoped to environments where possible (production secrets only available to production deploy jobs).
- Rotation: define rotation cadence per secret class. Document in `runbooks/secrets-rotation.md`.
- Audit: secret usage is logged. Review who/what accessed what at least quarterly.

## Container hardening

- Base images: pinned by digest (`sha256:...`), not just tag. Tags are mutable.
- Minimal base: `distroless`, `alpine`, or scratch. Full `ubuntu:latest` is forbidden in production images.
- Run as non-root. `USER` directive in Dockerfile, and verify in healthcheck.
- No package managers (`apt`, `apk`) in final image. Multi-stage build — install in builder, copy artefacts to minimal runtime.
- Vulnerability scan in CI (Trivy, Grype). Critical findings block deploy.

## Network

- Default-deny ingress. Open only required ports.
- Service-to-service communication: mTLS or service-mesh equivalent.
- Public endpoints behind a WAF.
- TLS 1.2 minimum. Old protocols (`SSLv3`, `TLSv1.0`, `TLSv1.1`) disabled.

## CI/CD

- Workflows from forks don't get secrets (`pull_request_target` is dangerous — review every use).
- Third-party actions pinned by SHA, not tag.
- Required status checks include security scans.

## Logging & monitoring

- Auth failures, authz failures, anomalous error rates — all alertable.
- Audit log retention meets compliance (project-specific; document in `runbooks/`).
- Logs themselves are protected — write-only for app, read-restricted to ops team.

## Validation

OPS-side `validate/security.sh` runs:
```bash
trivy image --severity CRITICAL,HIGH --exit-code 1 $IMAGE
hadolint Dockerfile
# Check workflows for unpinned actions
grep -rE "uses: [a-z-]+/[a-z-]+@v?[0-9]" .github/workflows/ && exit 1 || true
```
