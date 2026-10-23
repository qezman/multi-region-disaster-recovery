data "aws_caller_identity" "current" {}

# sets up the replication rule that intercepts container updates
resource "aws_ecr_replication_configuration" "api" {
  replication_configuration {
    rule {
      destination {
        region      = var.destination_region
        registry_id = data.aws_caller_identity.current.account_id
      }
      # clone repositories matching the project name prefix
      repository_filter {
        filter      = var.project
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

