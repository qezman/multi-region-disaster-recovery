data "aws_caller_identity" "current" {}

module "network" {
  source = "../../modules/network"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "app_stack" {
  source = "../../modules/app-stack"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  # Uses the replicated ECR endpoint automatically maintained by the global cross-region setup
  image         = "${data.aws_caller_identity.current.account_id}.dkr.ecr.eu-central-1.amazonaws.com/dr-project-api:v2"
  region_name   = "eu-central-1"
  desired_count = 1
}
