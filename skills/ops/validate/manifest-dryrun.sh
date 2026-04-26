#!/usr/bin/env bash
# manifest-dryrun.sh — runs the appropriate dry-run for the detected stack.
# Auto-detects: terraform, kubernetes manifests, wrangler config, etc.

set -euo pipefail

errors=0
ran_anything=0

# ─── Terraform ──────────────────────────────────────────────────────────────
tf_files=$(find . -type f -name '*.tf' \
           -not -path './.terraform/*' -not -path './.git/*' 2>/dev/null || true)

if [[ -n "$tf_files" ]]; then
  if command -v terraform >/dev/null; then
    echo "Terraform plan..."
    ran_anything=1

    tf_dirs=$(echo "$tf_files" | xargs -n1 dirname | sort -u)
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      pushd "$dir" > /dev/null
      
      # Init if not already (silent)
      if [[ ! -d ".terraform" ]]; then
        terraform init -backend=false -input=false > /dev/null 2>&1 || true
      fi
      
      # Validate (catches syntax errors, missing vars)
      if ! terraform validate; then
        errors=$((errors + 1))
        popd > /dev/null
        continue
      fi
      
      popd > /dev/null
    done <<< "$tf_dirs"
  else
    echo "  warn: terraform not installed; skipping plan"
  fi
fi

# ─── Kubernetes manifests ───────────────────────────────────────────────────
k8s_files=$(find . -type f \( -name '*.yaml' -o -name '*.yml' \) \
            -path '*k8s*' -o -path '*kubernetes*' -o -path '*manifests*' 2>/dev/null \
            | grep -v node_modules | grep -v '.git' || true)

if [[ -n "$k8s_files" ]]; then
  if command -v kubectl >/dev/null; then
    echo "Kubernetes manifests client-side validation..."
    ran_anything=1
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      # Client-side dry-run; doesn't need cluster access
      if ! kubectl apply --dry-run=client -f "$f" > /dev/null 2>&1; then
        echo "  ✗ kubectl validation failed: $f"
        errors=$((errors + 1))
      fi
    done <<< "$k8s_files"
  else
    echo "  warn: kubectl not installed; skipping manifest validation"
  fi
fi

# ─── Kustomize ──────────────────────────────────────────────────────────────
kustomize_files=$(find . -type f -name 'kustomization.yaml' 2>/dev/null \
                  | grep -v node_modules || true)

if [[ -n "$kustomize_files" ]]; then
  if command -v kubectl >/dev/null; then
    echo "Kustomize build..."
    ran_anything=1
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      dir=$(dirname "$f")
      if ! kubectl kustomize "$dir" > /dev/null 2>&1; then
        echo "  ✗ kustomize build failed: $dir"
        errors=$((errors + 1))
      fi
    done <<< "$kustomize_files"
  fi
fi

# ─── Wrangler (Cloudflare) ──────────────────────────────────────────────────
if [[ -f "wrangler.toml" ]]; then
  if command -v wrangler >/dev/null; then
    echo "Wrangler dry-run..."
    ran_anything=1
    if ! wrangler deploy --dry-run --outdir /tmp/wrangler-out > /dev/null 2>&1; then
      echo "  ✗ wrangler deploy --dry-run failed"
      errors=$((errors + 1))
    fi
    rm -rf /tmp/wrangler-out
  else
    echo "  warn: wrangler not installed; skipping"
  fi
fi

# ─── Helm ───────────────────────────────────────────────────────────────────
helm_charts=$(find . -type f -name 'Chart.yaml' 2>/dev/null \
              | grep -v node_modules || true)

if [[ -n "$helm_charts" ]]; then
  if command -v helm >/dev/null; then
    echo "Helm template dry-run..."
    ran_anything=1
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      dir=$(dirname "$f")
      if ! helm template test "$dir" > /dev/null 2>&1; then
        echo "  ✗ helm template failed: $dir"
        errors=$((errors + 1))
      fi
    done <<< "$helm_charts"
  fi
fi

if [[ $ran_anything -eq 0 ]]; then
  echo "manifest-dryrun: skip (no recognised IaC stack detected)"
  exit 0
fi

[[ $errors -eq 0 ]] && echo "manifest-dryrun: ok" && exit 0
echo "manifest-dryrun: $errors issue(s)"
exit 1
