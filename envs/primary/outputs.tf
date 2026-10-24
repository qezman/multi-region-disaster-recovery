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

output "db_subnet_group_name" {
  value = module.network.db_subnet_group_name
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository where the application image must be pushed"
  value       = aws_ecr_repository.api.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name of the primary ALB"
  value       = module.app-stack.alb_dns_name
}