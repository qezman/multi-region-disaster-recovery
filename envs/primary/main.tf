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
}