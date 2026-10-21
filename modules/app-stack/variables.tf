variable "project" {
  description = "Project name used as a prefix on all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnets"
  type        = list(string)
}

variable "container_port" {
  type    = number
  default = 3000
}