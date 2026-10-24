provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      project = var.project
      env     = var.environment
      region  = "eu-west-1"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = "eu-central-1"

  default_tags {
    tags = {
      project = var.project
      env     = var.environment
      region  = "eu-west-1"
    }
  }
}