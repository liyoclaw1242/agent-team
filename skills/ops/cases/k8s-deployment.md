# Case — Kubernetes Deployment

Deploying a service to GKE or EKS. The patterns are largely cluster-agnostic; cloud-specific bits are noted.

## Worked example: cancel-svc on GKE

A new Go service deployed as a Kubernetes Deployment behind a Service, exposed via Ingress, with HPA, PDB, and proper observability.

### Directory layout

```
infrastructure/
└── k8s/
    └── cancel-svc/
        ├── kustomization.yaml
        ├── base/
        │   ├── kustomization.yaml
        │   ├── namespace.yaml
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   ├── hpa.yaml
        │   ├── pdb.yaml
        │   ├── serviceaccount.yaml
        │   └── configmap.yaml
        └── overlays/
            ├── staging/
            │   ├── kustomization.yaml
            │   └── patches.yaml
            └── production/
                ├── kustomization.yaml
                └── patches.yaml
```

Kustomize is the default in this case; Helm is fine for charts you publish externally. For internal services, kustomize keeps things straightforward.

### `base/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cancel-svc
  labels:
    app: cancel-svc
spec:
  # replicas managed by HPA in production; set in overlays
  selector:
    matchLabels:
      app: cancel-svc
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0     # never reduce capacity during rollout
      maxSurge: 25%         # add up to 25% extra during rollout
  template:
    metadata:
      labels:
        app: cancel-svc
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      serviceAccountName: cancel-svc
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: cancel-svc
          image: gcr.io/PROJECT/cancel-svc:PLACEHOLDER  # patched per overlay
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 9090
              name: metrics
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: cancel-svc-db
                  key: url
            - name: STRIPE_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: stripe-secret-key
                  key: latest
          envFrom:
            - configMapRef:
                name: cancel-svc-config
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              # CPU intentionally not limited (let it burst); memory is hard limit
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /livez
              port: http
            initialDelaySeconds: 10
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 2
          # Graceful shutdown: give the process 25s before SIGKILL
          # (depends on app handling SIGTERM correctly)
          lifecycle:
            preStop:
              exec:
                command: ["sleep", "10"]   # delay so traffic drains via readiness flip
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
      terminationGracePeriodSeconds: 30
```

### What's good about this

**`maxUnavailable: 0`**: never reduce serving capacity during rollout. Combined with `maxSurge: 25%`, you over-provision briefly during rollout instead of running short.

**`runAsNonRoot: true` + `runAsUser: 65532`**: matches the distroless `nonroot` user in the Dockerfile. K8s admission policies (PodSecurityStandards "restricted") enforce this.

**`readOnlyRootFilesystem: true`**: prevents writes to container FS. Combined with `emptyDir` mount on `/tmp`, the app can write where it legitimately needs to and nowhere else.

**`drop: ["ALL"]`**: drops all Linux capabilities. Add specific ones back if absolutely needed (`NET_BIND_SERVICE` for bind <1024).

**Distinct probes**:
- `livenessProbe` — restarts on failure; should be permissive (only restart if truly stuck)
- `readinessProbe` — removes from service routing; should be strict (route only when fully ready)

**`preStop` sleep + `terminationGracePeriodSeconds: 30`**: when k8s sends SIGTERM, readiness probe flips immediately (k8s removes pod from service), then preStop's 10s sleep allows in-flight requests to drain via existing connections, then SIGTERM, then up to 30s for clean shutdown, then SIGKILL.

**Secrets via `secretKeyRef`** not env literals: see `rules/secrets-discipline.md`.

**Memory limit set, CPU not**: CPU limits cause throttling that hurts latency more than it helps. Memory limits are necessary (OOMKill is preferable to runaway memory). Modern advice; some teams disagree — that's fine, document why.

### `base/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cancel-svc
  labels:
    app: cancel-svc
spec:
  type: ClusterIP
  selector:
    app: cancel-svc
  ports:
    - port: 80
      targetPort: http
      name: http
```

ClusterIP keeps the service internal. External exposure happens via Ingress (or via API gateway in many setups).

### `base/hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cancel-svc
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cancel-svc
  minReplicas: 3        # always 3 minimum for HA across zones
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300   # don't scale down rapidly
    scaleUp:
      stabilizationWindowSeconds: 0     # scale up immediately on need
```

`minReplicas: 3` ensures availability during zone disruptions (3 zones, one replica per zone typically). Lower is acceptable for non-critical services.

### `base/pdb.yaml`

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: cancel-svc
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: cancel-svc
```

PDB ensures node-drain operations (cluster upgrades, evictions) keep at least 2 replicas serving. Without PDB, a node drain can take down all replicas of a 3-replica service simultaneously.

### Overlay: `production/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
  - ../../base

patches:
  - path: patches.yaml

images:
  - name: gcr.io/PROJECT/cancel-svc
    newTag: REPLACED_BY_CI   # CI/CD updates this
```

The `images:` directive lets CI bump the image tag without editing other YAML.

### Overlay: `production/patches.yaml`

```yaml
- op: replace
  path: /spec/template/spec/containers/0/resources/requests/cpu
  value: 200m
- op: replace
  path: /spec/template/spec/containers/0/resources/requests/memory
  value: 512Mi
- op: replace
  path: /spec/template/spec/containers/0/resources/limits/memory
  value: 1Gi
```

Production overrides resource sizing.

## Apply commands

```bash
# Dry-run server-side
kubectl apply -k infrastructure/k8s/cancel-svc/overlays/production --dry-run=server

# Real apply
kubectl apply -k infrastructure/k8s/cancel-svc/overlays/production

# Watch rollout
kubectl rollout status deployment/cancel-svc -n production
```

## Service mesh and ingress

If your cluster has a service mesh (Istio, Linkerd), additional resources are needed: VirtualService, DestinationRule, etc. Beyond the scope of this case — the mesh's own docs are authoritative.

For ingress without a mesh:

### GKE: Google Cloud Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cancel-svc
  annotations:
    kubernetes.io/ingress.class: "gce"
    networking.gke.io/managed-certificates: "cancel-svc-cert"
    kubernetes.io/ingress.global-static-ip-name: "cancel-svc-ip"
spec:
  rules:
    - host: cancel-svc.example.com
      http:
        paths:
          - path: /*
            pathType: ImplementationSpecific
            backend:
              service:
                name: cancel-svc
                port:
                  number: 80
```

GCP-managed certificates are cheaper and easier than DIY cert-manager + Let's Encrypt.

### EKS: ALB Ingress Controller

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cancel-svc
  annotations:
    kubernetes.io/ingress.class: "alb"
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:region:account:certificate/UUID"
spec:
  rules: [...]
```

EKS uses ALB controller annotations to translate Ingress to ALB resources.

## Common K8s mistakes

### Mistake: only one replica

```yaml
replicas: 1
```

A single-replica deployment dies during any node drain, restart, or upgrade. Even for non-critical services, `replicas: 2` minimum.

### Mistake: no PDB

Without PDB, k8s upgrades / node maintenance can take all replicas offline simultaneously. PDB doesn't cost anything to add.

### Mistake: no anti-affinity

By default, k8s may schedule all replicas on the same node. If that node fails, total outage. Use:

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: cancel-svc
                topologyKey: kubernetes.io/hostname
```

`preferred` (not `required`) so the scheduler can still schedule when nodes are constrained.

### Mistake: no resource requests

Pods without `requests` are scheduled with the assumption they need nothing; they overcrowd nodes. Always set requests, even modest ones.

### Mistake: liveness probe that hits app dependencies

```yaml
livenessProbe:
  httpGet:
    path: /healthz   # which queries the database
```

If the database has a hiccup, every pod fails liveness, every pod restarts, the cluster cascades. Liveness should check ONLY whether the process can answer (`/livez` returns 200 if the HTTP server runs); readiness checks dependencies (`/readyz` includes DB ping).

## GKE vs EKS: differences worth knowing

| Concern | GKE | EKS |
|---------|-----|-----|
| Cluster control plane mgmt | Fully managed (free for Autopilot, $73/mo for Standard) | Managed ($73/mo) |
| Ingress controller default | Google Cloud Ingress (GCE LB) | ALB Ingress Controller (must be installed) |
| TLS certs default | Google-managed certs | AWS Certificate Manager (ACM) |
| Container registry | Artifact Registry | ECR |
| Workload identity | GKE Workload Identity (clean) | IRSA (more setup) |
| Node auto-upgrade | Automatic + clean | Managed node groups, requires more setup |
| Logging | Cloud Logging integration | CloudWatch (or 3rd party) |

GKE is generally less operational overhead for typical workloads. EKS is the default in AWS shops.

## Anti-patterns

- **Treating manifests as static config** — they're code; review every change like code
- **Editing live with `kubectl edit` and forgetting to update the YAML** — IaC drift; future PR conflicts; "why is prod different"
- **Skipping resource limits** — accept the consequences (OOM, throttle); explicit > implicit
- **Single replica in production** — see above
- **No PDB** — see above
- **Liveness probes that depend on external services** — cascading restart hazard
- **`latest` tag in image** — non-reproducible deploys; rollback requires knowing what `latest` was
