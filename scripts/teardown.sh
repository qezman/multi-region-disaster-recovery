#!/usr/bin/env bash

# destroy secondary, then primary, then list anything billable that's left
# global (DNS, certs) and bootstrap (state bucket) stay up
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export AWS_PROFILE=${AWS_PROFILE:-dr-project}

# image_tag has no default, but its value doesn't matter when destroying
terraform -chdir="$ROOT/envs/secondary" destroy -var image_tag=teardown
terraform -chdir="$ROOT/envs/primary"   destroy -var image_tag=teardown

echo "== leftovers (each line should be [])"
for R in eu-west-1 eu-central-1; do
  aws rds   describe-db-instances   --region $R --query 'DBInstances[].DBInstanceIdentifier' --output json
  aws elbv2 describe-load-balancers --region $R --query 'LoadBalancers[].LoadBalancerName' --output json
done