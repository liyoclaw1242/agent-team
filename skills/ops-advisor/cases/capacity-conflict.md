# Case — Capacity Conflict

A request that, taken at face value, would exceed current infrastructure capacity. ops-advisor's job is to surface the conflict numerically and propose paths that fit within or expand capacity.

## The consultation

Parent issue #1010: "Add image-processing on user uploads — generate 5 thumbnail sizes for every product image. Should support 1000 products/day with up to 20 images per product."

arch-shape opened consultation #1011 to ops-advisor:

```
- Does our infra support image processing at this scale?
- Where should the processing happen?
- Capacity / cost implications?
```

## Phase 1 — Investigate

```bash
# Existing image / file processing
grep -r "imagemagick\|libvips\|image_processing\|thumbnail" services/
# → no existing image processing in any service

# Existing object store / file infra
grep -r "s3\|gcs\|cloudflare-r2\|storage" terraform/ k8s/
# → terraform/storage/main.tf provisions an S3 bucket: product-images
# → no CDN configured directly; S3 with public read

# Cluster capacity
kubectl describe nodes | grep -A2 "Allocated resources"
# → 4 nodes (n2-standard-8: 8 vCPU, 32GB RAM each)
# → currently ~75% CPU, ~60% memory committed
# → headroom: ~8 vCPU, ~50GB RAM cluster-wide

# Existing compute-heavy workloads
grep -A2 "resources:" k8s/services/*/deployment.yaml | grep -i cpu | sort -u
# → most services request 100-500m CPU
# → none currently > 1 CPU per pod
# → no GPU node pool

# Async processing infra
grep -r "rabbitmq\|kafka\|sqs\|pubsub" k8s/ helm/
# → RabbitMQ exists, used for orders/payments async work

# Background worker patterns
ls k8s/services/ | grep -i worker
# → 2 workers exist: payment-webhook-worker, email-worker
# → both small workloads

# Queue capacity
# rabbitmq cluster: 1 instance, 2 vCPU, 4GB RAM (helm values)
# Current peak ~1000 msgs/sec; configured limit 5000 msgs/sec

# CDN / caching
ls infra/cdn/ 2>/dev/null
# → no CDN configured
```

## Phase 2 — Calculate the numbers

```
Request: 1000 products/day × 20 images/product = 20,000 images/day
For each image: generate 5 thumbnail sizes = 100,000 thumbnails/day
Per-image processing time (estimate, libvips): 200-500ms per resize
       = 1-2.5 seconds for 5 thumbs per image

Daily compute time:
  20,000 images × 2 sec average = 40,000 sec/day = 11 CPU-hours/day

If processed sequentially: 11 hours of single-CPU work per day
If processed in 4-hour window: needs ~3 CPUs running continuously

Storage:
  Original image average: ~500KB-2MB
  5 thumbs per image average: ~50KB total
  20,000 originals + 100,000 thumbs daily
  ~100GB/day raw, but most is product images stored anyway
  Net new from thumbs: ~5GB/day

Egress (CDN missing):
  100,000 thumbs/day × 30KB avg × 100 view/thumb = 300GB/day egress
  Without CDN, all from S3 — significant cost
```

## Phase 3 — Compose response

```markdown
## Advice from ops-advisor

### Existing constraints

- No image processing infrastructure exists in cluster prod-tw-1.
  Verified by grep: no imagemagick / libvips / thumbnail libraries in
  any service.
- Object store: terraform/storage/main.tf provisions S3 bucket
  `product-images`. Public read. No CDN configured (no infra/cdn/
  directory; no Cloudfront / Cloudflare integration).
- Cluster capacity: 4 nodes (n2-standard-8). ~75% CPU committed,
  ~60% memory. Headroom: ~8 vCPU, ~50GB RAM. Cluster autoscaler
  configured 2-8 nodes.
- All current pod resource requests are 100-500m CPU. No GPU
  node pool. No node pool sized for compute-heavy workloads.
- RabbitMQ exists (helm/rabbitmq, 2 vCPU/4GB single instance).
  Currently handles orders + payments async work. Headroom: ~4000
  msgs/sec (currently ~1000 peak).
- 2 background workers exist (payment-webhook-worker, email-worker);
  both lightweight (200m CPU each). The pattern of "stateless worker
  consuming from RabbitMQ" is established.

### Suggested approach

Computed load (per investigation):
- 100,000 thumbnails/day = ~11 CPU-hours/day
- If spread evenly: ~0.5 CPU continuously
- If batch processed (typical product upload patterns): peaks of
  ~3 CPU during upload bursts

Recommended approach: **dedicated thumbnail worker following existing
RabbitMQ-worker pattern**:

- New service: thumbnail-worker (stateless, consumes from
  `images.thumbnail-jobs` queue)
- 2-4 replicas with HPA on queue depth (scale up under burst)
- Resource request: 1 CPU, 1GB RAM per pod (sized for libvips)
- Existing RabbitMQ handles queue (well within capacity)
- Existing S3 bucket for storage (existing path patterns)
- Image processing library: libvips (significantly faster than ImageMagick,
  similar API)
- Retry strategy: 3 retries on failure, dead-letter queue for permanent fails

Cluster impact:
- New worker requires up to 4 CPU (4 replicas × 1 CPU peak)
- Headroom: 8 CPU available; fits comfortably
- Memory: 4GB total; fits

**Critical missing piece — CDN**: 100,000 thumbnails/day × downstream
view count = significant egress. Without a CDN:
- Cost: at ~$0.09/GB AWS egress, 300GB/day = ~$810/month just for
  thumbnail egress (rough estimate; depends on view multiplier)
- Latency: every thumbnail request hits S3; no caching
- Capacity: S3 has request rate limits (100 GET/sec/prefix without
  prefix randomization)

Strongly recommend introducing CDN as part of this work, or at minimum
as the immediate next ops task. CloudFront in front of S3 is the
straightforward path; ~1 day of work; reduces costs dramatically.

### Conflicts with request

- Request describes thumbnail generation as if it's a single feature.
  In reality it has three concerns: processing, storage, delivery.
  Storage is fine (existing S3); processing fits cluster capacity;
  delivery (CDN) is missing infrastructure that needs adding.
- "1000 products/day with up to 20 images" — peak concurrency
  matters more than daily total. If 100 products are uploaded in a
  burst (say, daily catalog import), 2000 images need processing
  in a tight window. The 4-replica HPA strategy handles this if
  the burst is < 5 minutes; for longer bursts, autoscaler kicks in.
  Recommend arch-shape clarify upload patterns (steady state vs
  bursty) before finalising worker count.
- If image processing is "synchronous from upload" (user waits), the
  compute capacity matters for latency p99, not throughput. The
  request implies async (pre-generated thumbs) which is the right
  pattern.

### Estimated scope

- M — ~7 manifests + 1 new infra commitment:
  - thumbnail-worker Deployment + Service + ConfigMap (3)
  - HPA manifest (1)
  - PrometheusRule + ServiceMonitor (2)
  - RabbitMQ queue resource (1)
  - existing S3 bucket: no change
  - **CDN provisioning (CloudFront in front of S3): separate work**

CDN work is itself S-M scope:
  - Terraform module for CloudFront distribution (~3 resources)
  - DNS configuration for CDN domain
  - S3 bucket policy update for CDN access
  - Cache invalidation strategy

Total this PR + CDN PR: ~10-15 manifests across 2 PRs. Could land in
parallel.

If processing is one-off (catalog migration only, not ongoing):
  - S — could be a one-shot Job manifest, no persistent worker
  - But request implies ongoing (1000/day), so rule out

### Risks

- Capacity: HPA on queue depth handles bursts; autoscaler handles
  sustained increase. But if a viral upload pattern hits (say 100,000
  images in an hour during a sale event), the existing capacity
  is exceeded. Worth load-testing at 5x expected peak before launch.
- Cost: image processing is CPU-bound; CPU-bound workloads on
  general-purpose nodes are reasonable but not optimal. If volume
  grows 10x, consider compute-optimized node pool. For current
  scale, default pool is fine.
- Egress without CDN: as computed, ~$810/month estimated for naive
  egress. This is a cost surprise if CDN isn't part of launch.
- libvips memory: large source images can spike memory beyond the
  1GB/pod limit. Recommend image size validation upstream (reject
  sources > 50MB at upload) and OOM-safe processing in worker.
- S3 request rate limits: 100 GET/sec/prefix without prefix
  randomization. With CDN in front, this is fine. Without CDN,
  could hit limits at high read traffic.
- Rollback: thumbnail generation is additive (old code still serves
  full-size images if thumbs missing). Rolling back the worker just
  pauses thumbnail creation. Low rollback risk.
- Disk: each pod will use temp space for processing (1-5MB scratch
  per image). Pod ephemeral storage limit should be set to 1GB+ to
  avoid eviction.

### Drift noticed

- terraform/storage/main.tf provisions the S3 bucket but doesn't
  configure lifecycle policies; old/unused images accumulate. Worth
  noting for follow-up.
- arch-ddd has no media / asset-handling documentation. Image
  processing decisions aren't recorded anywhere; this consultation's
  decisions should be added to arch-ddd.
- No CDN despite a public-facing storefront is itself drift between
  "production-ready" expectations and reality. This may be a known
  pre-MVP gap; if so, this consultation is the trigger to address it.
```

## Phase 4 — Validate + post

```bash
bash actions/respond.sh \
  --issue 1011 \
  --advice-file /tmp/advice-issue-1011.md
```

## What this case demonstrates

- **Computed real numbers**: didn't say "high traffic"; calculated 11 CPU-hours/day
- **Distinguished concerns**: processing fits, storage fits, delivery (CDN) doesn't exist — surfaced as 3 separate problems
- **Surfaced a missing prerequisite**: CDN absence is a separate ops task; advisor flagged it as required, not optional
- **Cost estimation**: rough $810/month figure makes the CDN need concrete
- **Capacity headroom analysis**: cluster has room; sized appropriately
- **Multiple risk dimensions**: capacity, cost, request limits, memory, rollback, disk — comprehensive
- **Recommended a load test**: at 5x peak; concrete number, not "should test"
- **Drift cluster**: 3 separate drifts identified, each actionable

## Key lessons for capacity-conflict consultations

1. Always compute the numbers; don't say "high" or "low" without quantity
2. Distinguish between processing, storage, and delivery — each has different capacity profiles
3. Surface missing prerequisites (CDN here) as required scope, not nice-to-have
4. Estimate cost in dollars where reasonable; cost is the most actionable risk dimension
5. Recommend specific load tests with multipliers (5x peak, 10x peak) — concrete acceptance criteria
6. Capacity decisions affect node pool decisions; if the workload doesn't fit existing pools, surface that
7. Some capacity issues hide other issues (S3 request rate without CDN); follow the dependency chain
