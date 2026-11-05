# Runbook

Everything runs from `project-a` in WSL. The scripts use the `dr-project` AWS profile by default.

## Every session

```bash
sudo hwclock -s       # WSL's clock drifts after Windows sleeps, which breaks AWS requests
scripts/deploy.sh     # build the image, apply primary, secondary and global
scripts/migrate.sh    # only after a fresh spin-up: creates the transfers table (safe to rerun)
scripts/verify.sh     # PASS/FAIL checks across both regions
```

End of the day:

```bash
scripts/teardown.sh   # destroys secondary, then primary, and lists anything left
```

Terraform asks you to type `yes` at every apply and destroy. Anything else cancels it.

## What the scripts do

| Script | What it does |
|---|---|
| `deploy.sh` | Tags the image with the current commit (`TAG=v5` to override), builds and pushes it unless it's already in ECR, waits until eu-central-1 has the identical image, then applies primary, secondary and global |
| `migrate.sh` | Runs `migrate.js` as a one-off ECS task in primary. The standby gets the table through replication |
| `verify.sh` | Health in both regions, a POST through the domain, the standby reading it back, the standby refusing writes, and both regions on the same image |
| `teardown.sh` | Destroys secondary then primary, then checks for leftover databases and load balancers |

## Why this order

- Primary before secondary: secondary replicates primary's database and takes the password from primary's outputs.
- Secondary before global: global points DNS at both load balancers.
- Teardown in reverse: destroying primary first promotes the read replica and breaks secondary's next plan.
- Global and bootstrap stay up: they hold DNS, certificates and every state file.

## First time only

```bash
cd bootstrap && terraform init && terraform apply && cd ..
cd envs/global && terraform init
terraform apply -target=aws_ecr_replication_configuration.api \
                -target=aws_route53_record.dr_delegation \
                -target=aws_acm_certificate_validation.primary \
                -target=aws_acm_certificate_validation.secondary
cd ../..
terraform -chdir=envs/primary init && terraform -chdir=envs/secondary init
```

Global is targeted the first time because its failover records need load balancers that don't exist yet, and ECR replication must exist before the first image push. After that, follow "Every session".

## Running Terraform by hand

Primary and secondary need the image tag: `terraform plan -var image_tag=$(git rev-parse --short HEAD)`.

## After teardown

Expected leftovers: the eu-central-1 ECR repo (created by replication, not Terraform), KMS keys pending deletion for 7 days (not billed), and everything in `global` and `bootstrap`.

## When something fails

| Symptom | Cause | Fix |
|---|---|---|
| `Apply cancelled` | the prompt got something other than `yes` | rerun the script; finished steps are skipped or show no changes |
| `app/ has uncommitted changes` | the image tag is the commit, so `app/` must be committed | commit, or `TAG=v5 scripts/deploy.sh` |
| `eu-central-1 doesn't have the same ... image` | ECR replication missing or slow | make sure `envs/global` is applied, then rerun |
| `UnknownError` with an empty `RequestID` | network blip or WSL clock drift | `sudo hwclock -s`, then rerun |
| `Unsupported attribute` on `terraform_remote_state` | an env ran before the one it reads | follow the order above |
| `Apply envs/primary first, then secondary` | secondary planned before primary had its `db_password` output | apply primary first |
| ECS tasks fail with `AccessDeniedException` right after an apply | IAM changes take up to a minute to reach ECS | wait, ECS retries by itself |
| `already exists` on apply | leftovers from a destroy that stopped halfway | `terraform state list`, then import the resource or delete it in the console |
| `verify.sh` fails on the standby read | replication lag, or the secondary task is still starting | wait a minute and rerun `verify.sh` |