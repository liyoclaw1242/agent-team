#!/usr/bin/env bash
# lib.sh — small shared helpers for skill scripts. Source, don't execute.
#
# Usage: source "$(dirname "$0")/../../_shared/validate/lib.sh"

# Colors (only when stdout is a tty).
if [[ -t 1 ]]; then
  C_RED=$'\e[31m'
  C_GREEN=$'\e[32m'
  C_YELLOW=$'\e[33m'
  C_BLUE=$'\e[34m'
  C_RESET=$'\e[0m'
else
  C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_RESET=''
fi

log_info()  { printf '%s%s%s\n' "$C_BLUE" "INFO: $*" "$C_RESET"; }
log_warn()  { printf '%s%s%s\n' "$C_YELLOW" "WARN: $*" "$C_RESET" >&2; }
log_error() { printf '%s%s%s\n' "$C_RED" "ERROR: $*" "$C_RESET" >&2; }
log_ok()    { printf '%s%s%s\n' "$C_GREEN" "OK: $*" "$C_RESET"; }

die() {
  log_error "$*"
  exit 1
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null || die "required command not found: $cmd"
  done
}

require_env() {
  local var
  for var in "$@"; do
    [[ -n "${!var:-}" ]] || die "required env var not set: $var"
  done
}

# Run a command, log its name on failure with the exit code.
run() {
  local desc="$1"; shift
  if ! "$@"; then
    local rc=$?
    log_error "$desc failed (exit $rc): $*"
    return "$rc"
  fi
}
