resource "aws_route53_health_check" "primary" {
  fqdn              = data.terraform_remote_state.primary.outputs.alb_dns_name
  type              = "HTTPS"
  port              = 443
  resource_path     = "/health"
  request_interval  = 30
  failure_threshold = 3
  measure_latency   = true
  enable_sni        = true

  tags = {
    Name = "${var.project}-primary-health"
  }
}

resource "aws_route53_record" "primary" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id

  alias {
    name                   = data.terraform_remote_state.primary.outputs.alb_dns_name
    zone_id                = data.terraform_remote_state.primary.outputs.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = data.terraform_remote_state.secondary.outputs.alb_dns_name
    zone_id                = data.terraform_remote_state.secondary.outputs.alb_zone_id
    evaluate_target_health = true
  }
}