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

variable "github_repo" {
  description = "Repo allowed to deploy, as owner/name"
  type        = string
  default     = "qezman/multi-region-disaster-recovery"
}