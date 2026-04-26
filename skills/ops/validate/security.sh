#!/usr/bin/env bash
# security.sh — image + IaC security scans.

set -euo pipefail

errors=0

# ─── Trivy: image / fs scan ─────────────────────────────────────────────────
if command -v trivy >/dev/null; then
  echo "Trivy filesystem scan..."
  if ! trivy fs --severity HIGH,CRITICAL --exit-code 1 --skip-dirs node_modules,.terraform,.git . 2>&1 | grep -v '^$'; then
    errors=$((errors + 1))
  fi
else
  echo "  warn: trivy not installed (https://aquasecurity.github.io/trivy/)"
fi

# ─── Checkov: IaC scan (Terraform, Dockerfile, k8s YAML) ────────────────────
if command -v checkov >/dev/null; then
  echo "Checkov scan..."
  # --quiet only outputs failures; --soft-fail-on tests but doesn't exit nonzero on lower severity
  if ! checkov -d . --quiet \
       --framework terraform,dockerfile,kubernetes \
       --skip-check CKV_K8S_21 \
       2>&1; then
    errors=$((errors + 1))
  fi
else
  echo "  warn: checkov not installed (pip install checkov)"
fi

# ─── tfsec: Terraform-specific scan ────────────────────────────────────────
tf_files=$(find . -type f -name '*.tf' \
           -not -path './.terraform/*' -not -path './.git/*' 2>/dev/null || true)

if [[ -n "$tf_files" ]]; then
  if command -v tfsec >/dev/null; then
    echo "tfsec scan..."
    if ! tfsec . --soft-fail; then
      errors=$((errors + 1))
    fi
  else
    echo "  warn: tfsec not installed (https://github.com/aquasecurity/tfsec)"
  fi
fi

# ─── Hadolint Dockerfile security ──────────────────────────────────────────
# (Already runs in lint.sh; this is here for completeness if security.sh runs alone)
docker_files=$(find . -type f \( -name 'Dockerfile' -o -name 'Dockerfile.*' \) \
               -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null || true)

if [[ -n "$docker_files" ]] && command -v hadolint >/dev/null; then
  echo "Hadolint security checks..."
  while IFS= read -r f; do
    # Specifically security-relevant rules
    hadolint --config <(echo 'failure-threshold: error') "$f" || errors=$((errors + 1))
  done <<< "$docker_files"
fi

[[ $errors -eq 0 ]] && echo "security: ok" && exit 0
echo "security: $errors issue(s)"
exit 1
