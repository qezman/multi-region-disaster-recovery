output "vpc_id" {
  description = "The unique tracking ID assigned to the secondary regional network interface"
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the secondary ALB"
  value       = module.app_stack.alb_dns_name
}
