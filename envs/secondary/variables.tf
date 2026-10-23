variable "project" {
  description = "Project name used to isolate resource collections"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "The isolated network CIDR block boundary assigned to this regional VPC"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The vpc_cidr variable must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "availability_zones" {
  description = "List of availability zones to deploy subnets into"
  type        = list(string)
}