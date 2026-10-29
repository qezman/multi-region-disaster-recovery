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

# retrieves the AWS account ID
data "aws_caller_identity" "current" {}

# loads shared global infrastructure outputs from Terraform state
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "dr-project-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "global/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "secondary" {
  backend = "s3"
  config = {
    bucket = "dr-project-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "secondary/terraform.tfstate"
    region = "eu-west-1"
  }
}

# creates the primary-region VPC, subnets, and routing
module "network" {
  source             = "../../modules/network"
  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# deploys the primary-region application stack
module "app-stack" {
  source                 = "../../modules/app-stack"
  project                = var.project
  environment            = var.environment
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  image                  = "${aws_ecr_repository.api.repository_url}:v1"
  region_name            = "eu-west-1"
  desired_count          = 1
  certificate_arn        = data.terraform_remote_state.global.outputs.certificate_arn_primary
  database_secret_arn    = aws_secretsmanager_secret.db.arn
  secret_kms_key_arn     = module.database.kms_key_arn
  enable_database_secret = true
}

# deploys the primary-region database
module "database" {
  source                 = "../../modules/database"
  project                = var.project
  environment            = var.environment
  vpc_id                 = module.network.vpc_id
  db_subnet_group_name   = module.network.db_subnet_group_name
  task_security_group_id = module.app-stack.task_security_group_id
}