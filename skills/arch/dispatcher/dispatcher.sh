#!/usr/bin/env bash
# dispatcher.sh — pure-bash router for the agent-team facade.
#
# WHAT IT DOES
#   Polls GitHub for issues matching `agent:arch + status:ready`, classifies each
#   one against decision-table.md, and re-tags the agent:* label so the
#   appropriate specialist (LLM-side) picks it up on its next poll.
#
# WHAT IT DOES NOT DO
#   - Call any LLM. Ever.
#   - Make routing decisions outside decision-table.md.
#   - Process post-implementation state (PR verdicts). That's pre-triage.sh.
#
# CONCURRENCY MODEL
#   - flock guards against two cron jobs running at once on this host.
#   - Per-issue re-read check (TOCTOU guard) ensures we don't overwrite labels
#     that changed between our classify-time read and our route-time write.
#   - Shares its lock file with pre-triage.sh and scan-*.sh — the orchestrator
#     processes are mutually exclusive, since they all mutate labels.
#
# EXIT CODES
#   0 — clean run (zero or more issues routed)
#   1 — fatal env / config error
#   2 — partial failure (some issues routed, some failed)

set -euo pipefail

# ─── Config (override via env) ──────────────────────────────────────────────
: "${REPO:?REPO must be set, e.g. owner/repo}"
: "${LOCK_FILE:=/tmp/arch-orchestrator-${REPO//\//-}.lock}"
: "${LOG_FILE:=/tmp/dispatcher-${REPO//\//-}.log}"
: "${ROUTE_SH:=}"
: "${ISSUE_META_SH:=}"
: "${DRY_RUN:=0}"
: "${MAX_ISSUES_PER_RUN:=50}"

AGENT_ID="dispatcher"

# ─── Logging ────────────────────────────────────────────────────────────────
log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] $*" | tee -a "$LOG_FILE" >&2
}

die() { log "FATAL: $*"; exit 1; }

# ─── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
  command -v gh >/dev/null || die "gh CLI not found"
  command -v jq >/dev/null || die "jq not found"
  command -v flock >/dev/null || die "flock not found"
  gh auth status >/dev/null 2>&1 || die "gh not authenticated"

  # Locate route.sh
  if [[ -z "$ROUTE_SH" ]]; then
    if   [[ -x "$HOME/.claude/scripts/route.sh" ]]; then ROUTE_SH="$HOME/.claude/scripts/route.sh"
    elif [[ -x "scripts/route.sh"               ]]; then ROUTE_SH="$(pwd)/scripts/route.sh"
    else die "route.sh not found; set ROUTE_SH"
    fi
  fi
  [[ -x "$ROUTE_SH" ]] || die "ROUTE_SH=$ROUTE_SH not executable"

  # Locate issue-meta.sh
  if [[ -z "$ISSUE_META_SH" ]]; then
    if   [[ -x "$HOME/.claude/skills/_shared/actions/issue-meta.sh" ]]; then ISSUE_META_SH="$HOME/.claude/skills/_shared/actions/issue-meta.sh"
    elif [[ -x "skills/_shared/actions/issue-meta.sh"               ]]; then ISSUE_META_SH="$(pwd)/skills/_shared/actions/issue-meta.sh"
    else die "issue-meta.sh not found; set ISSUE_META_SH"
    fi
  fi
  [[ -x "$ISSUE_META_SH" ]] || die "ISSUE_META_SH=$ISSUE_META_SH not executable"
}

# ─── Lock (concurrency layer 1) ─────────────────────────────────────────────
acquire_lock() {
  exec 200>"$LOCK_FILE" || die "cannot open lock file $LOCK_FILE"
  if ! flock -n 200; then
    log "another orchestrator process is running; exiting cleanly"
    exit 0
  fi
}

# ─── Issue inspection ───────────────────────────────────────────────────────
get_labels() {
  gh issue view "$1" --repo "$REPO" --json labels \
    --jq '[.labels[].name] | join(" ")'
}

get_body() {
  gh issue view "$1" --repo "$REPO" --json body --jq '.body // ""'
}

get_intake_kind() {
  REPO="$REPO" "$ISSUE_META_SH" get "$1" intake-kind 2>/dev/null || true
}

get_source() {
  local labels="$1"
  echo " $labels " | grep -oE 'source:[a-z-]+' | head -n1 | sed 's/^source://' || true
}

body_has_feedback() {
  echo "$1" | grep -qE 'Technical Feedback from'
}

has_label() {
  local labels="$1" target="$2"
  [[ " $labels " == *" $target "* ]]
}

# ─── Classification ─────────────────────────────────────────────────────────
# Implements the decision table. Returns target agent (without "agent:" prefix)
# on stdout. Defaults to arch-judgment if nothing matches.
#
# Inputs:
#   $1 = labels (space-separated)
#   $2 = body (raw markdown, includes HTML comments)
#   $3 = intake-kind (extracted via issue-meta.sh)
classify() {
  local labels="$1" body="$2" intake_kind="$3"

  # Rule 0: Feedback signal overrides everything else (post-impl pushback).
  if body_has_feedback "$body"; then
    echo "arch-feedback"; return 0
  fi

  # Rule 1: audit findings → arch-audit
  if [[ "$intake_kind" == "qa-audit" || "$intake_kind" == "design-audit" ]]; then
    echo "arch-audit"; return 0
  fi

  # Rule 2: business intake → arch-shape
  if [[ "$intake_kind" == "business" ]]; then
    echo "arch-shape"; return 0
  fi

  # Rule 3: architecture intake → arch-shape
  if [[ "$intake_kind" == "architecture" ]]; then
    echo "arch-shape"; return 0
  fi

  # Rule 4: bug intake — routes to debug, not arch-shape.
  # Note: bugs should arrive on agent:debug directly, not agent:arch. If we
  # see one on agent:arch, escalate to judgment for investigation.
  if [[ "$intake_kind" == "bug" ]]; then
    echo "arch-judgment"; return 0
  fi

  # Rule 5 (escape hatch): unknown kind → arch-judgment
  echo "arch-judgment"
}

# ─── Routing ────────────────────────────────────────────────────────────────
route_to() {
  local n="$1" target="$2" reason="$3"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY_RUN: would route #$n to agent:$target ($reason)"
    return 0
  fi

  if "$ROUTE_SH" "$n" "$target" \
       --repo "$REPO" \
       --agent-id "$AGENT_ID" \
       --reason "$reason" 2>>"$LOG_FILE"; then
    log "routed #$n → agent:$target"
    return 0
  fi
  log "ERROR: route.sh failed for #$n → $target"
  return 1
}

# ─── Per-issue ──────────────────────────────────────────────────────────────
process_issue() {
  local n="$1"

  # Read 1: classify-time snapshot
  local labels_before body intake_kind
  labels_before=$(get_labels "$n") || { log "skip #$n: cannot read labels"; return 1; }
  body=$(get_body "$n")             || { log "skip #$n: cannot read body"; return 1; }
  intake_kind=$(get_intake_kind "$n")

  local target
  target=$(classify "$labels_before" "$body" "$intake_kind")

  log "classify #$n: intake-kind=${intake_kind:-<none>} → agent:$target"

  # No-op: already at target
  if has_label "$labels_before" "agent:$target"; then
    log "skip #$n: already at agent:$target"
    return 0
  fi

  # Read 2: TOCTOU guard
  local labels_now
  labels_now=$(get_labels "$n") || { log "skip #$n: cannot re-read"; return 1; }
  if [[ "$labels_now" != "$labels_before" ]]; then
    log "skip #$n: labels changed during classification — will retry next tick"
    return 0
  fi

  # Build human-readable reason
  local reason
  if body_has_feedback "$body"; then
    reason="feedback signal in body"
  elif [[ -n "$intake_kind" ]]; then
    reason="intake-kind=$intake_kind"
  else
    reason="no recognised classification — escape hatch"
  fi

  route_to "$n" "$target" "$reason"
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
  preflight
  acquire_lock

  log "dispatcher start (repo=$REPO, dry_run=$DRY_RUN)"

  local issues
  issues=$(gh issue list --repo "$REPO" \
             --label "agent:arch" \
             --label "status:ready" \
             --state open \
             --limit "$MAX_ISSUES_PER_RUN" \
             --json number \
             --jq '.[].number') || die "gh issue list failed"

  if [[ -z "$issues" ]]; then
    log "no candidate issues; exiting"
    exit 0
  fi

  local count=0 failed=0
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    count=$((count + 1))
    if ! process_issue "$n"; then
      failed=$((failed + 1))
    fi
  done <<< "$issues"

  log "dispatcher end: $count processed, $failed failed"
  [[ $failed -eq 0 ]] && exit 0 || exit 2
}

main "$@"
