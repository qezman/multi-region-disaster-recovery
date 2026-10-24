data "aws_caller_identity" "current" {}

data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "dr-project-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "global/terraform.tfstate"
    region = "eu-west-1"
  }
}

# primary-region VPC, subnets, and routing from the shared network module
module "network" {
  source             = "../../modules/network"
  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "app-stack" {
  source            = "../../modules/app-stack"
  project           = var.project
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  image             = "${aws_ecr_repository.api.repository_url}:v1"
  region_name       = "eu-west-1"
  certificate_arn   = data.terraform_remote_state.global.outputs.certificate_arn_primary
}