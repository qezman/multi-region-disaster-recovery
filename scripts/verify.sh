#!/usr/bin/env bash

# end-to-end checks across both regions. PASS/FAIL per check, non-zero exit if any fail
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

# GitHub Actions passes credentials directly; locally, use the dr-project profile
[ -n "${CI:-}" ] || export AWS_PROFILE=${AWS_PROFILE:-dr-project}

DOMAIN=https://dr.qossim005.online
PRI=https://$(terraform -chdir="$ROOT/envs/primary" output -raw alb_dns_name)
SEC=https://$(terraform -chdir="$ROOT/envs/secondary" output -raw alb_dns_name)
BODY='{"amount":10000,"source_currency":"GBP","target_currency":"NGN","recipient":{"name":"Ada Obi","bank":"GTBank","account_number":"0123456789"}}'
FAILED=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1 ($2)"; FAILED=1; }

# 1-2. each region's health, straight to its load balancer (-k: the cert is for the domain, not the ALB name)
for target in "primary $PRI eu-west-1" "secondary $SEC eu-central-1"; do
  set -- $target
  out=$(curl -sk "$2/health")
  if echo "$out" | grep -q "\"region\":\"$3\""; then pass "$1 health"; else fail "$1 health" "$out"; fi
done

# 3. a write through the domain lands in primary
out=$(curl -s -w '\n%{http_code}' -X POST "$DOMAIN/transfers" -H "Idempotency-Key: $(cat /proc/sys/kernel/random/uuid)" \
  -H 'Content-Type: application/json' -d "$BODY")
code=$(echo "$out" | tail -n1)
ID=$(echo "$out" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
if [ "$code" = 201 ] && echo "$out" | grep -q '"served_by_region":"eu-west-1"'; then
  pass "POST via domain: 201 from eu-west-1"
else
  fail "POST via domain" "$(echo "$out" | head -n1) [$code]"
fi

# 4. the standby has it too (replication), and says it was created in primary
out=""
for _ in $(seq 1 10); do
  out=$(curl -sk "$SEC/transfers/$ID")
  echo "$out" | grep -q '"region":"eu-west-1"' && break
  sleep 2
done
if echo "$out" | grep -q '"region":"eu-west-1"' && echo "$out" | grep -q '"served_by_region":"eu-central-1"'; then
  pass "standby reads the new transfer (replication works)"
else
  fail "standby read" "$out"
fi

# 5. the standby refuses writes
code=$(curl -sk -o /dev/null -w '%{http_code}' -X POST "$SEC/transfers" -H "Idempotency-Key: $(cat /proc/sys/kernel/random/uuid)" \
  -H 'Content-Type: application/json' -d "$BODY")
if [ "$code" = 503 ]; then pass "standby refuses writes: 503"; else fail "standby write" "got $code"; fi

# 6. both services are running, on the same image
images=""
for R in eu-west-1 eu-central-1; do
  E=$([ $R = eu-west-1 ] && echo primary || echo secondary)
  read -r running desired taskdef < <(aws ecs describe-services --region $R --cluster dr-project-$E-cluster \
    --services dr-project-$E-service --query 'services[0].[runningCount,desiredCount,taskDefinition]' --output text)
  image=$(aws ecs describe-task-definition --region $R --task-definition "$taskdef" \
    --query 'taskDefinition.containerDefinitions[0].image' --output text)
  images="$images ${image##*:}"
  if [ "$running" = "$desired" ] && [ "$running" -ge 1 ]; then pass "$E running $running/$desired on ${image##*:}"; else fail "$E tasks" "running $running/$desired"; fi
done
set -- $images
if [ "$1" = "$2" ]; then pass "both regions run the same image ($1)"; else fail "image mismatch" "primary $1, secondary $2"; fi

if [ "$FAILED" = 0 ]; then echo "all checks passed"; else echo "some checks failed"; exit 1; fi