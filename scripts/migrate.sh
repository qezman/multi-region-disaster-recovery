#!/usr/bin/env bash

# run Bridge's migrations on primary's RDS with a one-off ECS task
# the standby gets it through replication
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-dr-project}
R=eu-west-1
CLUSTER=dr-project-primary-cluster

# reuse the service's subnets and security group, so the task can reach the DB
NET=$(aws ecs describe-services --region $R --cluster $CLUSTER --services dr-project-primary-service \
  --query 'services[0].networkConfiguration' --output json)

TASK=$(aws ecs run-task --region $R --cluster $CLUSTER --launch-type FARGATE \
  --task-definition dr-project-primary-task --network-configuration "$NET" \
  --overrides '{"containerOverrides":[{"name":"app","command":["node","scripts/migrate.ts"]}]}' \
  --query 'tasks[0].taskArn' --output text)

echo "== migration task started, waiting for it to finish"
aws ecs wait tasks-stopped --region $R --cluster $CLUSTER --tasks "$TASK"
EXIT=$(aws ecs describe-tasks --region $R --cluster $CLUSTER --tasks "$TASK" \
  --query 'tasks[0].containers[0].exitCode' --output text)

aws logs tail dr-project-primary-ecs --region $R --since 30m --log-stream-name-prefix "ecs/app/${TASK##*/}"

if [ "$EXIT" = 0 ]; then echo "migration OK"; else echo "migration failed (exit $EXIT)"; exit 1; fi