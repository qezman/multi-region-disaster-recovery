variable "project" {
  description = "Project name used as a prefix on all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC the database security group belongs to"
  type        = string
}

variable "db_subnet_group_name" {
  description = "DB subnet group to place the instance in"
  type        = string
}

variable "task_security_group_id" {
  description = "ECS task security group allowed to reach the database on 5432"
  type        = string
}

variable "replicate_source_arn" {
  description = "ARN of the source DB. When set, this instance becomes a read replica"
  type        = string
  default     = null
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Initial database name (primary only)"
  type        = string
  default     = "transfers"
}

variable "db_username" {
  description = "Master username (primary only)"
  type        = string
  default     = "dbadmin"
}