# Case — GCP Services

GCP-specific deployment patterns: Cloud Run for stateless services, Cloud SQL for managed Postgres, GCS for object storage. The case covers the most common shapes; deeper GCP-specific stuff lives in vendor docs.

## When GCP fits

Per `rules/platform-selection.md`:

- **Cloud Run**: stateless HTTP services, burst traffic, low baseline
- **GKE**: stateful, complex, multi-service (see `cases/k8s-deployment.md`)
- **Cloud SQL**: managed Postgres / MySQL with reasonable management overhead
- **GCS**: object storage; first choice within GCP ecosystem
- **Cloud Functions**: simple event-driven (Pub/Sub triggers, Cloud Storage triggers); for HTTP, prefer Cloud Run for control

This case focuses on Cloud Run + Cloud SQL + GCS as the typical stack.

## Cloud Run worked example

A stateless HTTP service deployed to Cloud Run via Terraform.

### Terraform

```hcl
resource "google_cloud_run_v2_service" "cancel_svc" {
  name     = "cancel-svc"
  location = "us-central1"
  project  = var.project_id

  template {
    service_account = google_service_account.cancel_svc.email

    scaling {
      min_instance_count = 1   # 0 for full scale-to-zero; 1 keeps a warm instance
      max_instance_count = 100
    }

    containers {
      image = "gcr.io/${var.project_id}/cancel-svc:${var.image_tag}"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true   # CPU only allocated during requests
        startup_cpu_boost = true   # extra CPU during cold start
      }

      ports {
        container_port = 8080
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "ENV"
        value = "production"
      }

      startup_probe {
        http_get {
          path = "/readyz"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/livez"
        }
        timeout_seconds   = 5
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    # VPC connector if the service needs to reach private resources (Cloud SQL, internal APIs)
    vpc_access {
      connector = google_vpc_access_connector.cancel_svc.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    # Concurrency: how many requests one instance handles at a time
    max_instance_request_concurrency = 80
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Service account for the service
resource "google_service_account" "cancel_svc" {
  account_id   = "cancel-svc"
  display_name = "Cancel Service"
  project      = var.project_id
}

# Grant access to specific secrets only
resource "google_secret_manager_secret_iam_member" "db_url_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cancel_svc.email}"
}

# Allow public access (or restrict to specific principals)
resource "google_cloud_run_service_iam_member" "public" {
  location = google_cloud_run_v2_service.cancel_svc.location
  project  = var.project_id
  service  = google_cloud_run_v2_service.cancel_svc.name
  role     = "roles/run.invoker"
  member   = "allUsers"   # public; or "serviceAccount:..." for restricted
}
```

### Notes on this config

**`min_instance_count: 1`**: keeps one instance warm. Avoids cold-start latency on first request after idle. Costs ~$X/mo for one always-running instance vs $0 with `min: 0`. Choose based on traffic profile.

**`cpu_idle: true`**: only allocate CPU during requests. Combined with `startup_cpu_boost: true`, this gets you cheap idle + fast cold starts.

**`max_instance_request_concurrency: 80`**: each instance handles up to 80 concurrent requests. Higher = fewer instances needed = cheaper, but more memory pressure per instance. 80 is a good default for I/O-bound services.

**VPC connector**: required if the service needs to reach private resources (Cloud SQL with private IP, internal services). Costs extra (~$15/mo for the connector). For Cloud SQL with public IP + IAM auth, you can skip the connector.

**Service account with narrow IAM**: per `rules/secrets-discipline.md`. The service account can only read the specific secrets it needs.

### Deploy via gcloud (alternative to Terraform)

```bash
# Build + push (or have CI do it)
gcloud builds submit --tag gcr.io/PROJECT/cancel-svc:TAG

# Deploy
gcloud run deploy cancel-svc \
  --image gcr.io/PROJECT/cancel-svc:TAG \
  --region us-central1 \
  --project PROJECT \
  --service-account cancel-svc@PROJECT.iam.gserviceaccount.com \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 1 \
  --max-instances 100 \
  --concurrency 80 \
  --set-secrets DATABASE_URL=db-url:latest \
  --no-allow-unauthenticated   # or --allow-unauthenticated for public
```

For ad-hoc; production deploys should be IaC.

## Cloud SQL worked example

Managed Postgres for the cancel-svc database.

### Terraform

```hcl
resource "google_sql_database_instance" "main" {
  name             = "billing-db"
  database_version = "POSTGRES_16"
  region           = "us-central1"
  project          = var.project_id

  settings {
    tier = "db-custom-2-7680"   # 2 vCPU, 7.5GB RAM

    availability_type = "REGIONAL"   # HA: failover replica in another zone
    disk_type         = "PD_SSD"
    disk_size         = 100
    disk_autoresize   = true
    disk_autoresize_limit = 500

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7      # Sunday
      hour         = 3      # 3am
      update_track = "stable"
    }

    ip_configuration {
      ipv4_enabled    = false           # only private IP
      private_network = google_compute_network.private.id
      require_ssl     = true
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"   # log queries >1s
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }

  deletion_protection = true
}

resource "google_sql_database" "billing" {
  name     = "billing"
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

# IAM user (preferred over password auth for service-to-service)
resource "google_sql_user" "cancel_svc" {
  name     = "cancel-svc@PROJECT.iam.gserviceaccount.com"
  instance = google_sql_database_instance.main.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
  project  = var.project_id
}
```

### Notes

**`availability_type = "REGIONAL"`**: HA — failover replica. Doubles cost but worth it for prod. Dev/staging can be `ZONAL`.

**`deletion_protection = true`**: prevents accidental destroy via Terraform. To intentionally delete, set to false in a separate apply.

**`point_in_time_recovery_enabled`**: lets you restore to any point in the last `transaction_log_retention_days`. Critical for "we ran an UPDATE that was wrong 30 minutes ago" cases.

**`ip_configuration.private_network`**: private IP only; access via VPC. Cloud Run uses the VPC connector.

**`database_flags.log_min_duration_statement = 1000`**: logs slow queries (>1s) to Cloud Logging. Essential for performance debugging.

**IAM user**: service account authenticates via IAM, not password. No password rotation needed. App uses Cloud SQL Auth Proxy or direct IAM auth in the SDK.

### Connection from Cloud Run

```go
// Go example using Cloud SQL Connector
import (
    "cloud.google.com/go/cloudsqlconn"
    _ "github.com/jackc/pgx/v5/stdlib"
    "database/sql"
)

func openDB() (*sql.DB, error) {
    cleanup, err := cloudsqlconn.RegisterDriver("cloudsql-postgres",
        cloudsqlconn.WithIAMAuthN())
    if err != nil { return nil, err }
    
    return sql.Open("cloudsql-postgres",
        "host=PROJECT:REGION:INSTANCE user=cancel-svc@PROJECT.iam dbname=billing")
}
```

The connector handles authentication automatically using the service account.

## GCS worked example

Object storage for user uploads or static assets.

### Terraform

```hcl
resource "google_storage_bucket" "uploads" {
  name     = "${var.project_id}-uploads"
  location = "US-CENTRAL1"
  project  = var.project_id

  uniform_bucket_level_access = true   # disables ACL-based; use IAM only

  public_access_prevention = "enforced"  # cannot be made public

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["https://app.example.com"]
    method          = ["GET", "PUT"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.uploads.id
  }
}

resource "google_storage_bucket_iam_member" "cancel_svc_access" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cancel_svc.email}"
}
```

### Notes

**`uniform_bucket_level_access`**: disables per-object ACLs. All access goes through IAM. Simpler model, fewer surprises.

**`public_access_prevention = "enforced"`**: bucket cannot be made public, period. Good default; remove only when you genuinely need public access.

**Lifecycle rules**: data ages out automatically. NEARLINE is cheaper storage class for less-accessed data. Auto-delete after 365d if appropriate for the use case.

**CORS**: required for browser uploads to work. Specify allowed origins; don't `*` unless you mean it.

**KMS encryption**: customer-managed encryption key. Slightly more secure than Google-managed (separates the key custody); also slightly more management.

### Signed URLs for uploads

For browser uploads, generate signed URLs server-side:

```go
// Go example
import "cloud.google.com/go/storage"

func uploadURL(ctx context.Context, key string) (string, error) {
    client, err := storage.NewClient(ctx)
    if err != nil { return "", err }
    
    return client.Bucket("PROJECT-uploads").SignedURL(key, &storage.SignedURLOptions{
        Method:  "PUT",
        Expires: time.Now().Add(15 * time.Minute),
        Headers: []string{"Content-Type:image/jpeg"},
    })
}
```

The browser PUTs directly to GCS using this URL. The backend never handles the file bytes.

## Networking patterns

### VPC for private resources

Cloud Run's VPC connector lets it reach Cloud SQL private IPs, internal Memorystore, etc. The connector is a small slice of bandwidth that bridges Cloud Run to the VPC.

```hcl
resource "google_vpc_access_connector" "main" {
  name           = "main-connector"
  region         = "us-central1"
  ip_cidr_range  = "10.8.0.0/28"
  network        = google_compute_network.private.id
  min_instances  = 2
  max_instances  = 10
  machine_type   = "e2-micro"
}
```

Cost: ~$15/mo for a small connector. Set `egress = "PRIVATE_RANGES_ONLY"` on the Cloud Run service to avoid routing public-internet traffic through the connector (which would also charge VPC egress).

### IAM patterns

Service accounts > user accounts for runtime access. Each service has its own SA; SAs are bound to specific permissions.

```hcl
# SA can read its own secrets only
resource "google_secret_manager_secret_iam_member" "db_url" {
  secret_id = google_secret_manager_secret.cancel_svc_db_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cancel_svc.email}"
}

# SA can publish to a specific topic
resource "google_pubsub_topic_iam_member" "publisher" {
  topic  = google_pubsub_topic.cancellations.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.cancel_svc.email}"
}
```

Avoid `roles/owner` or `roles/editor` at the project level for service accounts; they're too broad.

## Common mistakes

- **Cloud Run with `min_instances = 0` for low-traffic critical services** — cold starts during low traffic create user-facing latency
- **Public IP on Cloud SQL by default** — use private IP + VPC connector for production
- **Skipping `point_in_time_recovery`** — when you need it, you really need it
- **Public GCS buckets without encryption / public-access-prevention** — data leak hazard
- **Project-level Owner role for service accounts** — way too broad
- **Forgetting to set `deletion_protection: true` for Cloud SQL** — accidental Terraform changes destroying production DB has happened
- **Cloud Run concurrency = 1** — defaults higher; setting to 1 means one request per instance, way more instances needed, way higher cost
- **Backups not tested** — backup is configured but no one's verified restore actually works. Periodic restore drills.

## Cost considerations

GCP pricing is reasonably fair for small/medium workloads. Cost surprises usually come from:

- **Network egress**: especially cross-region or to internet
- **Idle Cloud SQL instances**: regional HA + larger tier adds up
- **Logging volumes**: `log_min_duration_statement` set too aggressively can spam logs
- **Snapshots**: backup retention beyond what you need

Set up billing alerts at 50%, 75%, 100% of monthly budget. Review cost reports monthly.
