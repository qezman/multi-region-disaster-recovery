variable "region" {
  description = "AWS region for S3 bucket"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  type        = string
  description = "prefix for resource names"
  default     = "dr-project"
}

variable "lock_table_state" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "dr-project-Terraform-locks"
}