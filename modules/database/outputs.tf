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

output "db_password" {
  description = "The generated database password"
  value = try(
    random_password.db[0].result,
    null
  )
  sensitive = true
}

output "db_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.this.address
}