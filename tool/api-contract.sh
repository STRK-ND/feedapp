#!/usr/bin/env bash
# HTTP contract for the Curated Feeds worker, exercised with curl against a
# local copy of the real worker (workers/dev-server.mjs). No network, no
# Cloudflare account, no wrangler — every route, method and error path below
# runs deterministically.
#
#   tool/api-contract.sh            # the full contract
#   tool/api-contract.sh --quick    # public reads and routing only
#
# Assertions are data-independent where the worker's answers depend on the
# live feed: they check the invariant, never a count that a refresh could
# change. Exits 0 when every check passes and prints one PASS/FAIL per check.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${CURATED_FEEDS_WORKER_PORT:-8791}"
BASE="http://127.0.0.1:${PORT}"
BODY_FILE="$(mktemp)"
trap 'rm -f "${BODY_FILE}"; [ -n "${SERVER_PID:-}" ] && kill "${SERVER_PID}" 2>/dev/null || true' EXIT
QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

pass=0; fail=0
request() { # request <METHOD> <path> [curl args...] -> body in $BODY_FILE
  local method="$1" path="$2"; shift 2
  curl -s -o "${BODY_FILE}" -w '%{http_code}' --max-time 30 -X "$method" "$@" "${BASE}${path}"
}
check() { # check <METHOD> <path> <expected-status> [curl args...]
  local method="$1" path="$2" want="$3"; shift 3
  local code; code="$(request "$method" "$path" "$@")"
  if [[ "$code" == "$want" ]]; then
    pass=$((pass + 1)); echo "PASS ${method} ${path} -> ${code}"
  else
    fail=$((fail + 1)); echo "FAIL ${method} ${path} -> ${code} (want ${want}) $(head -c 120 "${BODY_FILE}")"
  fi
}
contains() { # contains <METHOD> <path> <needle> [curl args...]
  local method="$1" path="$2" needle="$3"; shift 3
  local code body; code="$(request "$method" "$path" "$@")"; body="$(cat "${BODY_FILE}")"
  if [[ "$body" == *"$needle"* ]]; then
    pass=$((pass + 1)); echo "PASS ${method} ${path} carries ${needle}"
  else
    fail=$((fail + 1)); echo "FAIL ${method} ${path} (${code}) missing ${needle}: ${body:0:160}"
  fi
}
holds() { # holds <METHOD> <path> <node-expression over the parsed body> [curl args...]
  local method="$1" path="$2" expr="$3"; shift 3
  local code result
  code="$(request "$method" "$path" "$@")"
  # Parse the body locally so the expression reads against the real JSON.
  result="$(cat "${BODY_FILE}" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const b=JSON.parse(s);const f=new Function("b",`return (${process.argv[1]})`);try{process.stdout.write(String(Boolean(f(b))))}catch(e){process.stdout.write("false")}})' "${expr}")"
  if [[ "$result" == "true" ]]; then
    pass=$((pass + 1)); echo "PASS ${method} ${path} holds ${expr}"
  else
    fail=$((fail + 1)); echo "FAIL ${method} ${path} (${code}) breaks ${expr}: $(head -c 200 "${BODY_FILE}")"
  fi
}

node "${ROOT}/workers/dev-server.mjs" --port "${PORT}" &
SERVER_PID=$!
# The store is in memory, so a server left over from another run would answer
# with another run's data. Fail loudly instead of asserting against it.
sleep 0.3
if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
  echo "FAIL could not start a worker on port ${PORT}: it is already in use."
  echo "     Stop that server, or set CURATED_FEEDS_WORKER_PORT=<free port>."
  exit 1
fi
for _ in $(seq 1 50); do
  curl -s -o /dev/null "${BASE}/health" && break
  sleep 0.1
done

API="x-api-secret: local-api-secret"
ADMIN="x-api-secret: local-admin-secret"
JSON="content-type: application/json"

echo "== routing and public reads =="
check GET /health 200
check GET /articles 200
check GET /sources 200
check GET / 404
check GET /unknown 404
check POST /articles 404 --header "$JSON" --data-binary '{}'
check PUT /articles 404 --header "$JSON" --data-binary '{}'
check OPTIONS /articles 204

echo "== pagination and filtering =="
check GET '/articles?page=1&pageSize=2' 200
holds GET '/articles?page=1&pageSize=2' 'b.items.length === 2'
holds GET '/articles?page=1&pageSize=2' 'b.items.length <= b.total'
holds GET '/articles?page=999' 'b.items.length === 0 && b.hasMore === false'
holds GET '/articles?source=verge' 'b.items.length > 0 && b.items.length < b.total && b.items.every(a => a.sourceId === "verge") && b.items.length === Math.min(50, b.total)'
holds GET '/articles?source=__nope__' 'b.items.length === 0 && b.total === 0'
holds GET '/articles?sort=date_asc' 'b.items.every((a, i) => i === 0 || b.items[i - 1].pubDate <= a.pubDate)'
holds GET '/articles?q=zzzz-no-match' 'b.items.length === 0'
check GET '/articles?q=hinge' 200
contains GET '/articles?q=hinge' 'Hinge report'

echo "== app-level routes fail closed without a secret =="
check GET /articles/refresh 401
check POST /subscribe 401 --header "$JSON" --data-binary '{"token":"abcdefghijklmnop"}'
check PUT /sources 401 --header "$JSON" --data-binary '{"sources":[]}'

if [[ $QUICK == 1 ]]; then
  echo; echo "quick mode: ${pass} passed, ${fail} failed (app routes skipped)"
  [[ $fail == 0 ]] || exit 1
  exit 0
fi

echo "== app authority (x-api-secret = API_SECRET) =="
check GET /articles/refresh 200 --header "$API"
check POST /subscribe 200 --header "$API" --header "$JSON" --data-binary '{"token":"abcdefghijklmnop"}'
check DELETE /subscribe 200 --header "$API" --header "$JSON" --data-binary '{"token":"abcdefghijklmnop"}'
check POST /subscribe 400 --header "$API" --header "$JSON" --data-binary '{}'
# The app secret must not reach admin authority: PUT /sources stays locked.
check PUT /sources 401 --header "$API" --header "$JSON" --data-binary '{"sources":[]}'

echo "== admin authority (x-api-secret = ADMIN_SECRET) =="
# An empty list is refused: the worker requires 1..50 sources.
check PUT /sources 400 --header "$ADMIN" --header "$JSON" --data-binary '{"sources":[]}'
check PUT /sources 200 --header "$ADMIN" --header "$JSON" --data-binary '{"sources":[{"id":"verge","name":"The Verge","url":"https://www.theverge.com/rss/index.xml","category":"Tech"}]}'
holds GET /sources 'b.sources.length === 1 && b.sources[0].name === "The Verge"'

echo
echo "${pass} checks passed, ${fail} failed"
[[ $fail == 0 ]] || exit 1
