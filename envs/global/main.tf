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

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Delegated zone for the DR project"
  lifecycle {
    prevent_destroy = true
  }
}

data "aws_route53_zone" "root" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_route53_record" "dr_delegation" {
  zone_id = data.aws_route53_zone.root.id
  name    = var.domain_name
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.main.name_servers
}
