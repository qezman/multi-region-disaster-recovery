provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      project = var.project
      env     = var.environment
      region  = "eu-central-1"
    }
  }
}