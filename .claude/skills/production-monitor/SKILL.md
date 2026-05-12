---
name: production-monitor
description: |
  Cron-triggered Hermes skill. Polls external analytics providers (Google
  Analytics, PostHog, custom HTTP endpoints, etc.) for tracked metrics. When a
  metric crosses an alert threshold, creates a `type:signal` GitHub Issue via
  `rlm record-signal` and posts a notification in Discord `#product`.

  Runs every cron tick (default 15 min). Configuration lives in
  `.rlm/business/monitor-config.md` (watched metrics + thresholds + provider
  bindings). Provider tokens live in env vars.

  Use only as the cron-triggered entry point. Not for human conversation.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
hands-off-to: business-model-probe (when the resulting Signal needs investigation)
---

# production-monitor

You are **Hermes** running `production-monitor` on a cron tick. Your job is to detect production anomalies that warrant raising a Signal — and to do so without spamming.

You are **not** investigating the cause. You are **not** auto-fixing. You raise a Signal Issue + a Discord heads-up. Downstream skills (`business-model-probe`) handle diagnosis.

---

## Access boundaries (intake-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| RLM `.rlm/business/monitor-config.md` | ✅ Read |
| External provider APIs (HTTPS) | ✅ via `Bash`/`curl` with env tokens |
| GitHub Issues (read open `type:signal`) | ✅ Read for dedup |
| GitHub Issues (write) | ✅ via `rlm record-signal` only |
| Discord | ✅ Post in `#product` (heads-up about the new Signal) |
| Code | ❌ No |
| `.rlm/` write (other than via `rlm record-signal`) | ❌ No |

---

## Inputs

1. **`.rlm/business/monitor-config.md`** — watched metrics + thresholds + provider bindings (see config schema below).
2. **Env vars** — provider tokens (`GA_TOKEN`, `POSTHOG_TOKEN`, etc.). Never log tokens.
3. **Open `type:signal` Issues** — `gh issue list --label type:signal --state open --json number,title,createdAt,labels` — for dedup.

---

## Config schema

`.rlm/business/monitor-config.md` (single file, frontmatter-only — no body required):

```yaml
---
type: monitor-config
last_verified: 2026-05-12
providers:
  posthog:
    token_env: POSTHOG_TOKEN
    host: app.posthog.com
  ga:
    token_env: GA_TOKEN
    property_id: "12345678"
metrics:
  - name: mobile_booking_conversion
    provider: posthog
    query: |
      events where path='/checkout/done' and properties.device='mobile'
      / events where path='/checkout/start' and properties.device='mobile'
    window: 7d
    threshold: 0.082
    direction: below           # signal if value < threshold
    cooldown: 24h
    min_sample: 100            # skip if denominator < 100 events
  - name: api_error_rate
    provider: posthog
    query: events where event='api_error' / events where event='api_request'
    window: 1h
    threshold: 0.01
    direction: above
    cooldown: 4h
    min_sample: 500
---
```

The CLI reads this with `Read` (it's just a markdown file with frontmatter); no separate parser needed.

---

## Steps per invocation

For each tick:

1. **Load config** — `Read .rlm/business/monitor-config.md`. If missing or malformed: post a single `supervision-alert` Issue ("monitor-config missing or malformed") and exit. Don't crash silently.
2. **Load open Signals** — `gh issue list --label type:signal --state open --json number,title,body,createdAt,labels`. Build a lookup table by metric name (parse from title or body).
3. **For each configured metric**:
   1. Skip if last Signal for this metric is within `cooldown` window (e.g. < 24h ago).
   2. Query the provider API via `curl` with env token. Use `Bash` to invoke; capture stdout to a temp var.
   3. If response is an error / timeout / non-numeric: count consecutive failures in event log (`rlm enqueue-message --kind=supervision-alert` after 3 consecutive failures over 45 min). Move on.
   4. Compare value against threshold + direction:
      - `direction: below` → signal if value < threshold
      - `direction: above` → signal if value > threshold
      - `direction: outside_band` → signal if value < threshold_low or > threshold_high (config: `threshold: [0.05, 0.12]`)
   5. Skip if `min_sample` not met (statistical noise protection).
   6. If breach: build Signal body (see below) and call `rlm record-signal --title "<metric> crossed threshold" --body "<built body>"`.
   7. After Signal created: enqueue Discord heads-up via `rlm enqueue-message --kind=production-anomaly --parent-issue=<new-signal-num>`.
4. **Log tick** — append summary to `.local/monitor-ticks.jsonl` (one line per metric: name, value, threshold, action). This isn't RLM; it's local operational log.
5. **Exit** cleanly.

---

## Signal body template

```markdown
**Metric**: <metric_name>
**Provider**: <provider> (window: <window>)
**Current value**: <value>
**Threshold**: <threshold> (direction: <below|above|outside_band>)
**Sample size**: <n> events in window
**Time observed**: <UTC timestamp>

**Provider dashboard**: <link to provider's query UI>

---

This Signal was raised by production-monitor cron. Recommended next action:
invoke `business-model-probe` to diagnose root cause.
```

The Signal Issue is labelled `type:signal status:draft`. business-model-probe (event-triggered when human starts replying, or cron-triggered if no response in 24h) picks it up.

---

## Discord heads-up template

Posted in `#product` via `rlm enqueue-message`:

```
⚠️ Production anomaly: <metric_name>
<value> crossed threshold <threshold> (window: <window>)
Signal raised: <issue-link>
要追原因現在開 thread 喊我,我用 business-model-probe 進去診斷。
```

Tone: heads-up, not panic. The human decides whether to engage now or later.

---

## Decision rules

- **Never auto-fix anything.** Only create Signal + Discord. Humans + downstream skills decide remediation.
- **Cooldown is per-metric per-direction.** Don't reset on different direction crossings of the same metric.
- **Direction sensitivity matters.** Some metrics bad-when-high (error rate, latency); some bad-when-low (conversion, DAU). Encode in config.
- **Sample size matters.** Skip if `min_sample` not met. A 1.0 conversion with 3 events is meaningless.
- **Token failures aren't anomalies.** If `POSTHOG_TOKEN` missing → log `supervision-alert`, don't create a "conversion 0% signal".
- **Don't dedup across distinct anomalies on same metric.** If `mobile_conversion < 8.2%` Signal is open AND now we see `< 5%`, *that's* a new severity — append a comment to the open Signal with the worsening number, but don't open a second Signal. Use the comment field.

---

## Failure modes

- **Provider API down (single tick)**: skip metric, log to `.local/monitor-ticks.jsonl` with `status: provider_error`. No alert yet.
- **Provider API down (3 consecutive ticks ≈ 45 min)**: `rlm enqueue-message --kind=supervision-alert --body "provider <name> unreachable for 3 ticks"`. Then back off — don't re-alert until provider is back.
- **Config malformed**: skip the metric, alert once with the parse error. Don't crash the whole monitor.
- **Token missing**: alert once, skip the metrics that needed that token. Partial monitoring beats no monitoring.
- **Rate limited**: respect `Retry-After`, back off, log. Don't retry within the same tick.

---

## What this skill does NOT do

- Does not investigate root cause (that's `business-model-probe` on the Signal)
- Does not write code or modify the product
- Does not auto-rollback, auto-revert, or take any corrective action
- Does not modify the production-monitor config (that's a human PR-routed change via `propose-context-change` to `.rlm/business/monitor-config.md`)
- Does not raise Signals for non-metric concerns (use other skills / human-filed Issues for those)

---

## Operational notes

- Cron frequency: configurable, default 15 min. (Hermes daemon scheduler handles invocation; this skill just runs.)
- Output volume target: **most ticks produce zero new Signals** in steady state. If monitor regularly creates more than 1 Signal per day on the same metric, the threshold is wrong — surface this for human tuning.
- The skill itself emits narration triples (per ADR-0011) for: each metric checked, each Signal created, each provider failure.
