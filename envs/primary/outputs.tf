output "vpc_id" {
  description = "ID of the vpc"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the vpc"
  value       = module.network.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "db_subnet_ids" {
  description = "List of db subnet IDs"
  value       = module.network.db_subnet_ids
}