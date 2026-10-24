output "name_servers" {
  value = aws_route53_zone.main.name_servers
}

output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "certificate_arn_primary" {
  value = aws_acm_certificate.primary.arn
}

output "certificate_arn_secondary" {
  value = aws_acm_certificate.secondary.arn
}