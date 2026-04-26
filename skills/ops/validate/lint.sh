#!/usr/bin/env bash
# lint.sh — OPS-flavoured: yamllint + hadolint + shellcheck + terraform fmt.
#
# Each tool is run if its target files are present; missing tools warn
# but don't fail (so the skill works in environments where not all tools
# are installed).

set -euo pipefail

errors=0

# ─── YAML files ─────────────────────────────────────────────────────────────
yaml_files=$(find . -type f \( -name '*.yaml' -o -name '*.yml' \) \
             -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null || true)

if [[ -n "$yaml_files" ]]; then
  echo "Linting YAML..."
  if command -v yamllint >/dev/null; then
    if ! echo "$yaml_files" | xargs yamllint --no-warnings; then
      errors=$((errors + 1))
    fi
  else
    echo "  warn: yamllint not installed (pip install yamllint)"
  fi
fi

# ─── Dockerfiles ────────────────────────────────────────────────────────────
docker_files=$(find . -type f \( -name 'Dockerfile' -o -name 'Dockerfile.*' \) \
               -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null || true)

if [[ -n "$docker_files" ]]; then
  echo "Linting Dockerfiles..."
  if command -v hadolint >/dev/null; then
    while IFS= read -r f; do
      if ! hadolint "$f"; then
        errors=$((errors + 1))
      fi
    done <<< "$docker_files"
  else
    echo "  warn: hadolint not installed (https://github.com/hadolint/hadolint)"
  fi
fi

# ─── Shell scripts ──────────────────────────────────────────────────────────
shell_files=$(find . -type f -name '*.sh' \
              -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null || true)

if [[ -n "$shell_files" ]]; then
  echo "Linting shell scripts..."
  if command -v shellcheck >/dev/null; then
    if ! echo "$shell_files" | xargs shellcheck; then
      errors=$((errors + 1))
    fi
  else
    echo "  warn: shellcheck not installed"
  fi
fi

# ─── Terraform ──────────────────────────────────────────────────────────────
tf_files=$(find . -type f -name '*.tf' \
           -not -path './.terraform/*' -not -path './.git/*' 2>/dev/null || true)

if [[ -n "$tf_files" ]]; then
  echo "Checking Terraform formatting..."
  if command -v terraform >/dev/null; then
    if ! terraform fmt -check -recursive .; then
      echo "  ✗ terraform fmt would change files; run 'terraform fmt -recursive .'"
      errors=$((errors + 1))
    fi
  else
    echo "  warn: terraform not installed"
  fi
fi

# ─── Wrangler config ────────────────────────────────────────────────────────
if [[ -f "wrangler.toml" ]]; then
  echo "Checking wrangler.toml..."
  if command -v wrangler >/dev/null; then
    if ! wrangler types > /dev/null 2>&1; then
      echo "  warn: wrangler types failed (config may be invalid)"
    fi
  fi
fi

# ─── Vercel config ──────────────────────────────────────────────────────────
if [[ -f "vercel.json" ]]; then
  echo "Validating vercel.json..."
  if command -v jq >/dev/null; then
    if ! jq empty vercel.json 2>/dev/null; then
      echo "  ✗ vercel.json is not valid JSON"
      errors=$((errors + 1))
    fi
  fi
fi

[[ $errors -eq 0 ]] && echo "lint: ok" && exit 0
echo "lint: $errors issue(s)"
exit 1
