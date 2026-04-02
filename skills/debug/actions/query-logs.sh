#!/bin/bash
# Query logs from Loki via HTTP API
# Usage: query-logs.sh '<LogQL>' '<duration>' [limit]
#
# Examples:
#   query-logs.sh '{service_name="api"} |= "error" | json' '1h'
#   query-logs.sh '{service_name="api"} | json | trace_id != ""' '30m' 50
set -e

LOKI_URL="${LOKI_URL:-http://localhost:3101}"

QUERY="${1:?LogQL query required}"
DURATION="${2:-1h}"
LIMIT="${3:-100}"

# Convert duration to nanosecond timestamps
NOW=$(date +%s)
case "$DURATION" in
  *h) SECS=$(( ${DURATION%h} * 3600 )) ;;
  *m) SECS=$(( ${DURATION%m} * 60 )) ;;
  *s) SECS=${DURATION%s} ;;
  *)  SECS=3600 ;;
esac
START=$(( NOW - SECS ))

ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")

echo "=== LogQL: ${QUERY} (last ${DURATION}) ==="
RESULT=$(curl -s "${LOKI_URL}/loki/api/v1/query_range?query=${ENCODED_QUERY}&start=${START}&end=${NOW}&limit=${LIMIT}")

echo "$RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
status = data.get('status', '?')
if status != 'success':
    print(f'Query failed: {data}')
    sys.exit(1)
streams = data.get('data', {}).get('result', [])
if not streams:
    print('No logs found.')
    sys.exit(0)
total = sum(len(s.get('values', [])) for s in streams)
print(f'Found {total} log line(s) across {len(streams)} stream(s):\n')
for stream in streams:
    labels = stream.get('stream', {})
    svc = labels.get('service_name', labels.get('job', '?'))
    for ts, line in stream.get('values', []):
        # Truncate long lines
        display = line[:200] + '...' if len(line) > 200 else line
        print(f'  [{svc}] {display}')
"
