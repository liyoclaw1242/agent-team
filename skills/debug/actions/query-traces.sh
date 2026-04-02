#!/bin/bash
# Query traces from Tempo via HTTP API
# Usage:
#   query-traces.sh '<TraceQL>' '<duration>'       — search traces
#   query-traces.sh --id <trace_id>                — get specific trace
#
# Examples:
#   query-traces.sh '{ resource.service.name = "api" && status = error }' '1h'
#   query-traces.sh '{ span.db.system = "postgresql" && duration > 500ms }' '2h'
#   query-traces.sh --id abc123def456
set -e

TEMPO_URL="${TEMPO_URL:-http://localhost:3200}"

if [ "$1" = "--id" ]; then
  TRACE_ID="${2:?Trace ID required}"
  curl -s "${TEMPO_URL}/api/traces/${TRACE_ID}" | python3 -m json.tool
  exit 0
fi

QUERY="${1:?TraceQL query required}"
DURATION="${2:-1h}"

# Convert duration to seconds for start/end calculation
NOW=$(date +%s)
case "$DURATION" in
  *h) SECS=$(( ${DURATION%h} * 3600 )) ;;
  *m) SECS=$(( ${DURATION%m} * 60 )) ;;
  *s) SECS=${DURATION%s} ;;
  *)  SECS=3600 ;;
esac
START=$(( NOW - SECS ))

ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")

echo "=== TraceQL: ${QUERY} (last ${DURATION}) ==="
RESULT=$(curl -s "${TEMPO_URL}/api/search?q=${ENCODED_QUERY}&start=${START}&end=${NOW}&limit=20")

echo "$RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
traces = data.get('traces', [])
if not traces:
    print('No traces found.')
    sys.exit(0)
print(f'Found {len(traces)} trace(s):\n')
for t in traces:
    tid = t.get('traceID', '?')
    root = t.get('rootServiceName', '?')
    name = t.get('rootTraceName', '?')
    dur = t.get('durationMs', 0)
    print(f'  {tid}  {root}/{name}  {dur}ms')
"
