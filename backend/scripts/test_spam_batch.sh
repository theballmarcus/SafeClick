#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT_DIR/.env"
  set +a
fi

API_URL="${API_URL:-http://127.0.0.1:3000}"
API_KEY="${API_KEY:-}"
MYSQL_USER="${MYSQL_USER:-}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_DATABASE="${MYSQL_DATABASE:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

if [[ -z "$API_KEY" ]]; then
  echo "FAIL: API_KEY is not set. Add it to .env or export it." >&2
  exit 1
fi

if [[ -z "$MYSQL_USER" || -z "$MYSQL_PASSWORD" || -z "$MYSQL_DATABASE" ]]; then
  echo "FAIL: MYSQL_USER, MYSQL_PASSWORD, and MYSQL_DATABASE must be set." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "FAIL: curl is required." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "FAIL: docker is required." >&2
  exit 1
fi

pass() {
  echo "PASS: $1"
}

warn() {
  echo "WARN: $1"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_status() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$message (expected HTTP $expected, got $actual)"
  fi
  pass "$message"
}

call_health() {
  local body_file
  body_file="$(mktemp)"
  local status
  status="$(curl -sS -o "$body_file" -w "%{http_code}" "$API_URL/health")"
  local body
  body="$(cat "$body_file")"
  rm -f "$body_file"

  assert_status "$status" "200" "GET /health returns 200"
  if ! grep -q '"ok":true' <<<"$body"; then
    fail "GET /health response should include ok=true"
  fi
  pass "GET /health response includes ok=true"
}

call_batch() {
  local payload="$1"
  local include_key="$2"

  local body_file
  body_file="$(mktemp)"

  local headers=( -H "Content-Type: application/json" )
  if [[ "$include_key" == "yes" ]]; then
    headers+=( -H "x-api-key: $API_KEY" )
  fi

  local status
  status="$(curl -sS -o "$body_file" -w "%{http_code}" "${headers[@]}" -d "$payload" "$API_URL/spam-mails/batch")"
  local body
  body="$(cat "$body_file")"
  rm -f "$body_file"

  echo "$status"
  echo "$body"
}

seed_test_mails() {
  local tag
  tag="$(date +%s)"

  local subject1="Training Payroll Verification ${tag}"
  local subject2="Mailbox Security Alert ${tag}"
  local subject3="Invoice Follow-up ${tag}"

  local insert_sql
  insert_sql="INSERT IGNORE INTO unique_mails (subject, sender_name, sender_email, body, real_url, is_phishing, hint, difficulty, category) VALUES
('$subject1', 'Finance Team', 'finance@corp-payroll-secure.com', 'Please verify your payroll account immediately to avoid suspension.', 'http://fake-payroll-check.com', 1, 'Urgency and external link', 'easy', 'payroll'),
('$subject2', 'IT Admin', 'it-security@mail-access-check.net', 'Unusual sign-in detected. Re-validate your mailbox credentials now.', 'http://mailbox-recover-now.com', 1, 'Credential harvesting language', 'medium', 'account'),
('$subject3', 'Accounts', 'billing@vendor-helpdesk.org', 'Your payment is overdue. Open attached portal to settle balance.', 'http://invoice-settlement-portal.com', 1, 'Pressure tactic and suspicious domain', 'hard', 'invoice');"

  docker compose exec -T db mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "$insert_sql" >/dev/null

  local ids_sql
  ids_sql="SELECT GROUP_CONCAT(id ORDER BY id) FROM unique_mails WHERE subject IN ('$subject1', '$subject2', '$subject3');"

  local ids
  ids="$(docker compose exec -T db mysql -N -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "$ids_sql" | tr -d '\r')"

  if [[ -z "$ids" || "$ids" == "NULL" ]]; then
    fail "Failed to seed or find test mails"
  fi

  echo "$ids"
}

all_phishing_ids() {
  docker compose exec -T db mysql -N -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SELECT GROUP_CONCAT(id ORDER BY id) FROM unique_mails WHERE is_phishing = 1;" | tr -d '\r'
}

if [[ -z "$(docker compose ps -q api)" || -z "$(docker compose ps -q db)" ]]; then
  fail "API and DB containers must be running. Start them with docker compose up -d"
fi

call_health

echo "Seeding training mails..."
seed_ids="$(seed_test_mails)"
first_seed_id="$(cut -d',' -f1 <<<"$seed_ids")"
pass "Seeded test mails with ids [$seed_ids]"

echo "Testing unauthorized /spam-mails/batch"
mapfile -t unauth_result < <(call_batch '{"count":2,"receivedMailIds":[]}' no)
unauth_status="${unauth_result[0]}"
unauth_body="${unauth_result[1]}"
assert_status "$unauth_status" "401" "POST /spam-mails/batch without key returns 401"
if ! grep -q 'Unauthorized' <<<"$unauth_body"; then
  fail "Unauthorized response should mention Unauthorized"
fi
pass "Unauthorized response body is correct"

echo "Testing authorized /spam-mails/batch"
mapfile -t auth_result < <(call_batch '{"count":2,"receivedMailIds":[]}' yes)
auth_status="${auth_result[0]}"
auth_body="${auth_result[1]}"
assert_status "$auth_status" "200" "POST /spam-mails/batch with key returns 200"
if ! grep -q '"mails":\[' <<<"$auth_body"; then
  fail "Authorized response should include mails array"
fi
pass "Authorized response includes mails array"

echo "Testing exclusion filtering"
mapfile -t exclusion_result < <(call_batch "{\"count\":2,\"receivedMailIds\":[${first_seed_id}]}" yes)
exclusion_status="${exclusion_result[0]}"
exclusion_body="${exclusion_result[1]}"
assert_status "$exclusion_status" "200" "POST /spam-mails/batch with receivedMailIds returns 200"
if grep -q "\"id\":${first_seed_id}" <<<"$exclusion_body"; then
  fail "Exclusion failed: response still includes excluded id ${first_seed_id}"
fi
pass "Exclusion filter removed id ${first_seed_id}"

echo "Testing exhaustion behavior"
all_ids="$(all_phishing_ids)"
if [[ -z "$all_ids" || "$all_ids" == "NULL" ]]; then
  fail "Could not fetch phishing IDs for exhaustion test"
fi

mapfile -t exhaustion_result < <(call_batch "{\"count\":2,\"receivedMailIds\":[${all_ids}]}" yes)
exhaustion_status="${exhaustion_result[0]}"
exhaustion_body="${exhaustion_result[1]}"

if [[ -z "$OPENAI_API_KEY" ]]; then
  assert_status "$exhaustion_status" "503" "Exhausted pool without OPENAI_API_KEY returns 503"
else
  if [[ "$exhaustion_status" == "200" ]]; then
    pass "Exhausted pool with OPENAI_API_KEY returns 200"
  elif [[ "$exhaustion_status" == "500" ]]; then
    warn "Exhausted pool triggered OpenAI path but upstream call failed (HTTP 500)."
    warn "Response: $exhaustion_body"
  else
    fail "Exhausted pool with OPENAI_API_KEY returned unexpected HTTP $exhaustion_status"
  fi
fi

if [[ "$exhaustion_status" == "503" ]]; then
  if ! grep -q 'OPENAI_API_KEY' <<<"$exhaustion_body"; then
    fail "503 exhaustion response should mention OPENAI_API_KEY"
  fi
  pass "503 exhaustion response explains missing OPENAI_API_KEY"
fi

echo "All tests completed successfully."
