# primary-region VPC, subnets, and routing from the shared network module
module "network" {
  source             = "../../modules/network"
  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}
