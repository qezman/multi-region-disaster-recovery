# creates the KMS key used to encrypt RDS data
resource "aws_kms_key" "rds" {
  description             = "RDS encryption key for ${var.project}-${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Name = "${var.project}-${var.environment}-rds"
  }
}

# creates a stable alias for the RDS KMS key
resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}