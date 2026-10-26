output "kms_key_arn" {
  description = "The ARN of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "kms_key_id" {
  description = "The ID of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "db_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.this.endpoint
}

output "db_security_group_id" {
  description = "The ID of the security group for the RDS instance"
  value       = aws_security_group.db.id
}

output "master_user_secret_arn" {
  description = "The ARN of the Secrets Manager secret for the master user"
 # safely returns null if the attribute doesn't exist on a replica
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}