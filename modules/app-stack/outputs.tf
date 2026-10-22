output "alb_dns_name" {
  description = "The public DNS record address of the ALB"
  value       = aws_lb.api.dns_name
}

output "alb_zone_id" {
  description = "The Route 53 Hosted Zone ID of the ALB"
  value       = aws_lb.api.zone_id
}

output "alb_arn" {
  description = "The ARN identifying the ALB"
  value       = aws_lb.api.arn
}

output "alb_security_group_id" {
  description = "The ID identifying the Load Balancer security group boundary"
  value       = aws_security_group.alb.id
}

output "task_security_group_id" {
  description = "The ID identifying the ECS Fargate container ASG"
  value       = aws_security_group.task.id
}

output "target_group_arn" {
  description = "The ARN identifying the routing target group"
  value       = aws_lb_target_group.api.arn
}

output "cluster_name" {
  description = "The name of the created ECS Fargate cluster"
  value = aws_ecs_cluster.api.name
}

output "service_name" {
  description = "The name of the ECS application service"
  value = aws_ecs_service.api.name
}