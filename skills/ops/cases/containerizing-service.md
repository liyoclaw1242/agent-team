# Case — Containerising a Service

Writing or improving a Dockerfile. The goal is a small, secure, reproducible image. Most language ecosystems have established multi-stage patterns — use them.

## Worked example: Go service

```dockerfile
# syntax=docker/dockerfile:1.6

# ─── Stage 1: build ────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Cache deps separately from source code
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

COPY . .

# Build with reproducibility flags + stripping
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    go build \
      -trimpath \
      -ldflags='-s -w -extldflags="-static"' \
      -o /out/cancel-svc \
      ./cmd/cancel-svc

# ─── Stage 2: runtime ──────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

# distroless: no shell, no package manager, minimal attack surface
COPY --from=builder /out/cancel-svc /cancel-svc

# Run as non-root (distroless 'nonroot' tag uses uid 65532)
USER nonroot:nonroot

# Document the port (does not actually publish)
EXPOSE 8080

# Healthcheck handled by k8s probes, not Docker HEALTHCHECK
# (HEALTHCHECK in image is irrelevant when k8s does its own probing)

ENTRYPOINT ["/cancel-svc"]
```

### What's good about this

**Multi-stage**: build and runtime are separate. The final image has only the compiled binary, not the Go toolchain or source. Image size: ~10MB vs ~600MB for a single-stage build with golang base.

**Cache mounts**: `--mount=type=cache` keeps Go module cache + build cache between builds. CI build time drops from ~3min to ~30s on cache hits.

**`CGO_ENABLED=0` + static**: produces a static binary that runs on distroless without libc. Without this, you'd need a glibc base.

**Distroless base**: no shell, no `apt`, no curl. Even if compromised, an attacker has nothing to work with. `distroless/static-debian12:nonroot` includes the `nonroot` user pre-configured.

**`-trimpath -ldflags='-s -w'`**: removes filesystem paths and debug symbols from the binary; smaller and harder to reverse-engineer.

**`USER nonroot`**: runs as UID 65532. K8s `runAsNonRoot: true` security context will reject root containers; this complies.

### What's NOT in it (deliberately)

- **`HEALTHCHECK`**: k8s does its own liveness/readiness probing; Docker's HEALTHCHECK is ignored in k8s. Skip it (one less thing to maintain).
- **Volumes**: should be configured at deployment time (k8s Volume), not in the image
- **`.env` files**: secrets come from runtime config, not baked in

## Worked example: Node.js service

```dockerfile
# syntax=docker/dockerfile:1.6

# ─── Stage 1: deps ─────────────────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# package files only — these change less often than source
COPY package.json package-lock.json ./

# Install only production deps (smaller; faster)
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

# ─── Stage 2: build ────────────────────────────────────────────────────────
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

COPY . .
RUN npm run build

# Strip dev deps post-build
RUN npm prune --omit=dev

# ─── Stage 3: runtime ──────────────────────────────────────────────────────
FROM node:20-alpine AS runtime

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 app && adduser -D -u 1001 -G app app

# Copy only what's needed
COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --from=build --chown=app:app /app/dist ./dist
COPY --from=build --chown=app:app /app/package.json ./package.json

USER app

EXPOSE 3000

# Use exec form so signals propagate
CMD ["node", "dist/index.js"]
```

### Notes

- Three stages: deps (production deps only — used if you have a leaner runtime path), build (full deps + bundle), runtime (final image)
- Node's official image doesn't have a "distroless" equivalent that works for all libraries; alpine is a reasonable trade-off
- `--chown=app:app` on COPY: avoids an extra `chown` step (saves layer)
- Exec-form CMD: signals (SIGTERM) propagate to the node process; without exec form, signals go to a shell wrapper and node may not shut down cleanly

### When to use distroless for Node

There's `gcr.io/distroless/nodejs20-debian12` — works for many Node services but breaks if you need any native modules with C deps (sharp, bcrypt, etc.). Test before committing.

## Worked example: Python service

```dockerfile
# syntax=docker/dockerfile:1.6

FROM python:3.12-slim AS builder

WORKDIR /build

# Install poetry / uv / pip-tools as preferred
RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

COPY . .
RUN uv sync --frozen --no-dev

# ─── Runtime ──────────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

WORKDIR /app

RUN groupadd -r app && useradd -r -g app -u 1001 app

# Copy from builder
COPY --from=builder --chown=app:app /build /app

USER app

ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Notes

- `python:X-slim`: smaller than full python image; usually sufficient
- `uv` is significantly faster than pip; use it where you can
- `PYTHONDONTWRITEBYTECODE=1`: skips `.pyc` files; smaller image
- `PYTHONUNBUFFERED=1`: stdout/stderr flushed immediately; logs visible in real-time

## Image security: validation

`validate/security.sh` runs trivy on the built image:

```bash
trivy image --severity HIGH,CRITICAL --exit-code 1 your-image:tag
```

CRITICAL findings should block the build; HIGH findings are warnings depending on context (some libraries have known issues with no fix; you accept the risk consciously).

For IaC-level checks, `checkov` and `tfsec` cover the Dockerfile too:

```bash
checkov -f Dockerfile --framework dockerfile
```

Catches: running as root, using `:latest` tag, missing USER, etc.

## Common Dockerfile mistakes

### Mistake: `latest` tag in FROM

```dockerfile
FROM node:latest    # NO
FROM node:20.11.1   # better — pin specific version
FROM node:20-alpine # acceptable — pinned major + variant
```

`:latest` makes builds non-reproducible; same Dockerfile builds different image at different times.

### Mistake: COPY then npm install

```dockerfile
COPY . .
RUN npm install   # NO — invalidates cache on every source change
```

```dockerfile
COPY package.json package-lock.json ./
RUN npm install
COPY . .          # better — cache hit when only source changes
```

Order COPY commands by frequency of change: least-changing first.

### Mistake: secrets in build args

```dockerfile
ARG GITHUB_TOKEN   # secret in build args
RUN git clone https://$GITHUB_TOKEN@github.com/...
```

Build args are visible in image history. Use BuildKit secrets:

```dockerfile
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/...
```

Pass at build time: `docker build --secret id=github_token,env=GITHUB_TOKEN`. Token isn't in image layers.

### Mistake: running as root

```dockerfile
USER 0          # implicit when no USER directive, in many bases
ENTRYPOINT ...
```

Set explicit non-root USER. K8s will reject root containers if `runAsNonRoot: true` is set.

### Mistake: huge final image

If your image is >500MB for a simple service, something is wrong:

- Multi-stage missing? You're shipping the build toolchain
- Wrong base? `ubuntu:22.04` is huge; `alpine` or `slim` or distroless usually fits
- Bundled large assets that should be in object storage instead

## Healthcheck endpoint

The image's binary should expose a `/health` (or `/livez` + `/readyz`) endpoint. K8s probes hit these.

Convention:
- `/livez` — am I alive (process can answer)? Restart on failure.
- `/readyz` — am I ready to serve (dependencies up, warmup done)? Don't route traffic until passing.
- `/health` — short-form for "all good" — used in simpler setups

## Anti-patterns

- **One-stage build** — ships build toolchain in final image
- **Pinned to `:latest`** — non-reproducible builds
- **`apt-get update` without `--no-install-recommends`** — pulls in extras
- **Running as root** — security hazard + k8s incompatibility
- **`HEALTHCHECK` in image instead of k8s probes** — wrong abstraction layer
- **Bundling secrets / config files** — secrets at runtime, not build
- **No `.dockerignore`** — sends huge build context to the daemon (incl. `.git`, `node_modules`)

A good `.dockerignore`:

```
.git
.github
node_modules
*.md
.env*
dist
build
coverage
.DS_Store
```

Keep build context small; build faster.
