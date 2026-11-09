#!/usr/bin/env bash
# promote the secondary read replica to a standalone, writable database. One-way: there's no undo
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-dr-project}
R=eu-central-1
DB=dr-project-secondary-db

read -rp "Promotion is one-way. Type 'promote' to continue: " answer
[ "$answer" = promote ] || { echo "cancelled"; exit 1; }

start=$(date -u +%s)
echo "T_promote_start $(date -u +%T)"
aws rds promote-read-replica --region $R --db-instance-identifier $DB > /dev/null

# done when it's available and no longer replicating from primary
while true; do
  read -r status source < <(aws rds describe-db-instances --region $R --db-instance-identifier $DB \
    --query 'DBInstances[0].[DBInstanceStatus,ReadReplicaSourceDBInstanceIdentifier]' --output text)
  echo "  $(date -u +%T)  $status  source=${source:-None}"
  if [ "$status" = available ] && { [ -z "${source:-}" ] || [ "$source" = None ]; }; then break; fi
  sleep 10
done

echo "T_promote_done $(date -u +%T) ($(( $(date -u +%s) - start ))s)"