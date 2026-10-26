#!/usr/bin/env bash
set -euo pipefail

# Check if an argument was provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 {fail|restore}"
    exit 1
fi

ACTION="$1"
CLUSTER="dr-project-primary-cluster"
SERVICE="dr-project-primary-service"
REGION="eu-west-1"

if [ "$ACTION" == "fail" ]; then
    echo "Scaling down primary service to 0..."
    aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --desired-count 0 --region "$REGION" > /dev/null
    echo "T0 (Failure Started): $(date +%T)"

elif [ "$ACTION" == "restore" ]; then
    echo "Scaling primary service back up to 1..."
    aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --desired-count 1 --region "$REGION" > /dev/null
    echo "T_restore (Recovery Started): $(date +%T)"

else
    echo "Error: Invalid argument '$ACTION'"
    echo "Usage: $0 {fail|restore}"
    exit 1
fi
