#!/bin/bash
# Quick load test wrapper — picks available tool automatically
# Usage: run-load-test.sh <URL> [VUS] [DURATION_SECONDS]
#
# Example:
#   run-load-test.sh http://localhost:8000/api/items 50 30
set -e

URL="${1:?Usage: run-load-test.sh <URL> [VUS] [DURATION_SECONDS]}"
VUS="${2:-50}"
DURATION="${3:-30}"

echo "═══ Load Test ═══"
echo "URL:      $URL"
echo "VUs:      $VUS"
echo "Duration: ${DURATION}s"
echo ""

# Pick available tool
if command -v k6 &>/dev/null; then
  echo "Tool: k6"
  echo ""

  K6_SCRIPT=$(mktemp /tmp/k6-XXXXXX.js)
  cat > "$K6_SCRIPT" << EOF
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: ${VUS},
  duration: '${DURATION}s',
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get('${URL}');
  check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
  });
  sleep(0.1);
}
EOF

  k6 run "$K6_SCRIPT"
  rm -f "$K6_SCRIPT"

elif command -v npx &>/dev/null; then
  echo "Tool: autocannon (via npx)"
  echo ""
  npx autocannon -c "$VUS" -d "$DURATION" "$URL"

elif command -v ab &>/dev/null; then
  echo "Tool: ab (Apache Bench)"
  echo ""
  TOTAL=$((VUS * DURATION))
  ab -n "$TOTAL" -c "$VUS" "$URL/"

else
  echo "ERROR: No load testing tool found."
  echo "Install one of: k6, autocannon (npx), or ab"
  exit 1
fi
