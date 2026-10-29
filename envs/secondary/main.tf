terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

data "aws_secretsmanager_secret" "db" {
  name = "dr-project/database-url"
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "dr-project-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "global/terraform.tfstate"
    region = "eu-west-1"
  }
}

module "network" {
  source = "../../modules/network"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "app-stack" {
  source = "../../modules/app-stack"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  # Uses the replicated ECR endpoint automatically maintained by the global cross-region setup
  image           = "${data.aws_caller_identity.current.account_id}.dkr.ecr.eu-central-1.amazonaws.com/dr-project-api:v2"
  region_name     = "eu-central-1"
  desired_count   = 1
  certificate_arn = data.terraform_remote_state.global.outputs.certificate_arn_secondary

  # database_secret_arn    = data.aws_secretsmanager_secret.db.arn
  database_secret_arn    = "arn:aws:secretsmanager:eu-central-1:722965867897:secret:dr-project/database-url"
  secret_kms_key_arn     = module.database.kms_key_arn
  enable_database_secret = true
}

module "database" {
  source = "../../modules/database"

  project                = var.project
  environment            = var.environment
  vpc_id                 = module.network.vpc_id
  db_subnet_group_name   = module.network.db_subnet_group_name
  task_security_group_id = module.app-stack.task_security_group_id
  # replicate_source_arn   = data.terraform_remote_state.primary.outputs.db_arn
  replicate_source_arn = "arn:aws:rds:eu-west-1:722965867897:db:dr-project-primary-db"
}