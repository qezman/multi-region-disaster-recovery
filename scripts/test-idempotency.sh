#!/usr/bin/env bash
# idempotency checks for POST /transfers. Run from project-a with the stack up
set -euo pipefail

BASE=${BASE:-http://localhost:3001}
PSQL=${PSQL:-docker compose exec -T postgres psql -U dbadmin -d transfers -tA}
RUN="ikey-$(date +%s)-$RANDOM" # fresh keys every run, so old rows never interfere
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAILED=0

BODY='{"amount":10000,"source_currency":"GBP","target_currency":"NGN","recipient":{"name":"Ada Obi","bank":"GTBank","account_number":"0123456789"}}'
OTHER='{"amount":25000,"source_currency":"GBP","target_currency":"NGN","recipient":{"name":"Ada Obi","bank":"GTBank","account_number":"0123456789"}}'

# post BODY KEY OUT: prints the status code, saves the body to OUT and the headers to OUT.h
post() {
  local key=()
  [ -n "$2" ] && key=(-H "Idempotency-Key: $2")
  curl -s -o "$3" -D "$3.h" -w '%{http_code}\n' -X POST "$BASE/transfers" \
    -H 'Content-Type: application/json' "${key[@]}" -d "$1"
}

id_of() { sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$1"; }
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1 ($2)"; FAILED=1; }

curl -sf "$BASE/health" > /dev/null || { echo "API not reachable at $BASE, is the stack up?"; exit 1; }

# 1. same key and body twice: 201 then 200, same id, replay header
K1="$RUN-1"
s1=$(post "$BODY" "$K1" "$TMP/1a")
s2=$(post "$BODY" "$K1" "$TMP/1b")
id1=$(id_of "$TMP/1a"); id2=$(id_of "$TMP/1b")
if [ "$s1" = 201 ] && [ "$s2" = 200 ] && [ -n "$id1" ] && [ "$id1" = "$id2" ] \
   && grep -qi '^idempotent-replay: true' "$TMP/1b.h"; then
  pass "1 same key and body: 201 then 200, same id ($id1)"
else
  fail "1 same key and body" "got $s1 then $s2, ids '$id1' and '$id2'"
fi

# 2. same key, different body: 422 idempotency_key_reuse
s=$(post "$OTHER" "$K1" "$TMP/2")
if [ "$s" = 422 ] && grep -q 'idempotency_key_reuse' "$TMP/2"; then
  pass "2 same key, different body: 422 idempotency_key_reuse"
else
  fail "2 same key, different body" "got $s: $(cat "$TMP/2")"
fi

# 3. 10 parallel requests with a new key: one 201, nine 200, one row, one id
K3="$RUN-3"
for i in $(seq 1 10); do post "$BODY" "$K3" "$TMP/3-$i" > "$TMP/3-$i.code" & done
wait
created=$(cat "$TMP"/3-*.code | grep -c '^201$' || true)
replayed=$(cat "$TMP"/3-*.code | grep -c '^200$' || true)
ids=$(for i in $(seq 1 10); do id_of "$TMP/3-$i"; done | sort -u | wc -l | tr -d ' ')
rows=$($PSQL -c "SELECT count(*) FROM transfers WHERE idempotency_key = '$K3'" | tr -d '[:space:]')
if [ "$created" = 1 ] && [ "$replayed" = 9 ] && [ "$ids" = 1 ] && [ "$rows" = 1 ]; then
  pass "3 10 parallel requests: 1 created, 9 replayed, 1 row"
else
  fail "3 10 parallel requests" "201s=$created 200s=$replayed distinct ids=$ids rows=$rows, codes: $(cat "$TMP"/3-*.code | tr '\n' ' ')"
fi

# 4. no key: 400
s=$(post "$BODY" "" "$TMP/4")
if [ "$s" = 400 ]; then pass "4 missing key: 400"; else fail "4 missing key" "got $s"; fi

if [ "$FAILED" = 0 ]; then echo "all idempotency checks passed"; else echo "some checks failed"; exit 1; fi
