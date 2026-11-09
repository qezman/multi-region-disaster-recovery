#!/usr/bin/env bash

# build Bridge (API and web app in one image) and apply primary, secondary and global
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
export AWS_PROFILE=${AWS_PROFILE:-dr-project}
REPO=dr-project-api
# Bridge lives in its own repos, beside multi-region-disaster-recovery
API_DIR=${API_DIR:-$ROOT/../../bridge-backend}
WEB_DIR=${WEB_DIR:-$ROOT/../../bridge-frontend}

# the tag is both repos' commits, so every image maps to exact code
if [ -z "${TAG:-}" ]; then
  for dir in "$API_DIR" "$WEB_DIR"; do
    if [ -n "$(git -C "$dir" -c core.fileMode=false -c core.autocrlf=input status --porcelain)" ]; then
      echo "$dir has uncommitted changes. Commit them first, or set a tag: TAG=v5 scripts/deploy.sh"
      exit 1
    fi
  done
  TAG=$(git -C "$API_DIR" rev-parse --short HEAD)-$(git -C "$WEB_DIR" rev-parse --short HEAD)
fi
echo "== deploying image tag $TAG to account $(aws sts get-caller-identity --query Account --output text)"

digest() {
  aws ecr describe-images --region "$1" --repository-name "$REPO" --image-ids "imageTag=$TAG" \
    --query 'imageDetails[0].imageDigest' --output text 2>/dev/null || true
}

echo "== primary: ECR repo"
terraform -chdir="$ROOT/envs/primary" apply -target=aws_ecr_repository.api -var "image_tag=$TAG"
ECR_URL=$(terraform -chdir="$ROOT/envs/primary" output -raw ecr_repository_url)

if [ -z "$(digest eu-west-1)" ]; then
  echo "== build and push $TAG"
  aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin "${ECR_URL%%/*}"
  docker buildx build --platform linux/amd64 --build-context web="$WEB_DIR" -t "$ECR_URL:$TAG" --load "$API_DIR"
  docker push "$ECR_URL:$TAG"
else
  echo "== $TAG is already in ECR, skipping the build"
fi

echo "== waiting for the same $TAG image in eu-central-1"
WANT=$(digest eu-west-1)
for _ in $(seq 1 36); do [ "$(digest eu-central-1)" = "$WANT" ] && break; sleep 5; done
if [ "$(digest eu-central-1)" != "$WANT" ]; then
  echo "eu-central-1 doesn't have the same $TAG image after 3 minutes. Check ECR replication (envs/global)."
  exit 1
fi

echo "== primary";   terraform -chdir="$ROOT/envs/primary"   apply -var "image_tag=$TAG"
echo "== secondary"; terraform -chdir="$ROOT/envs/secondary" apply -var "image_tag=$TAG"
echo "== global";    terraform -chdir="$ROOT/envs/global"    apply

echo "deployed $TAG. Next: scripts/migrate.sh (after a fresh spin-up), then scripts/verify.sh"