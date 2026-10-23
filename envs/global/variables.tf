variable "project" {
  description = "Project name used as a prefix on all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "destination_region" {
  description = "The target backup AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "domain_name" {
  description = "Delegated subdomain, e.g. dr.example.com"
  type        = string
}