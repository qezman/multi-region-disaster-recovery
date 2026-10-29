output "vpc_id" {
  description = "The unique tracking ID assigned to the secondary regional network interface"
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the secondary ALB"
  value       = module.app-stack.alb_dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the secondary ALB"
  value       = module.app-stack.alb_zone_id
}

output "db_arn" {
  value = module.database.db_arn
}

output "db_endpoint" {
  value = module.database.db_endpoint
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for RDS encryption in secondary region"
  value       = module.database.kms_key_arn
}