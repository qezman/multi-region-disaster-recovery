output "vpc_id" {
  description = "The unique tracking ID assigned to the secondary regional network interface"
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "The active URL route pointing to the secondary regional public facing load balancer"
  value       = module.app_stack.alb_dns_name
}
