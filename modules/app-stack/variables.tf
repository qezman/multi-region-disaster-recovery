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

variable "image" {
  description = "The fully qualified Docker image URI in ECR"
  type        = string
}

variable "desired_count" {
  description = "The target number of container instances to keep running"
  type        = number
  default     = 1
}

variable "region_name" {
  description = "The target region passed down into the running application container"
  type        = string
}