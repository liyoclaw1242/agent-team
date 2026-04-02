#!/bin/bash
# Query metrics from Prometheus via HTTP API
# Usage: query-metrics.sh '<PromQL>' '<duration>' [step]
#
# Examples:
#   query-metrics.sh 'sum(rate(http_server_request_duration_seconds_count{http_response_status_code=~"5.."}[5m]))' '2h'
#   query-metrics.sh 'histogram_quantile(0.99, sum(rate(http_server_request_duration_seconds_bucket{service_name="api"}[5m])) by (le))' '1h' '30s'
set -e

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9099}"

QUERY="${1:?PromQL query required}"
DURATION="${2:-1h}"
STEP="${3:-60s}"

NOW=$(date +%s)
case "$DURATION" in
  *h) SECS=$(( ${DURATION%h} * 3600 )) ;;
  *m) SECS=$(( ${DURATION%m} * 60 )) ;;
  *s) SECS=${DURATION%s} ;;
  *)  SECS=3600 ;;
esac
START=$(( NOW - SECS ))

ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")

echo "=== PromQL: ${QUERY} (last ${DURATION}, step ${STEP}) ==="
RESULT=$(curl -s "${PROMETHEUS_URL}/api/v1/query_range?query=${ENCODED_QUERY}&start=${START}&end=${NOW}&step=${STEP}")

echo "$RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
status = data.get('status', '?')
if status != 'success':
    print(f'Query failed: {data}')
    sys.exit(1)
results = data.get('data', {}).get('result', [])
if not results:
    print('No data points found.')
    sys.exit(0)
print(f'Found {len(results)} series:\n')
for series in results:
    metric = series.get('metric', {})
    label = ', '.join(f'{k}={v}' for k, v in metric.items()) or '(no labels)'
    values = series.get('values', [])
    if values:
        latest = values[-1][1]
        first = values[0][1]
        print(f'  {label}')
        print(f'    first={first}  latest={latest}  points={len(values)}')
"
