# Security Group Layout (Standalone Security Rules Style)

# sets up the security wall for load balancer
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Public ingress to the ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
  }
}

# opens up public port 80 so anyone on the internet can hit the web app via HTTP
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow public Internet traffic over HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# locks down the lb's exit paths so it can only talk to specific container app port.
resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id = aws_security_group.alb.id
  description       = "restrict ALB outbound traffic solely to ECS tasks on the application port"

  # Transport protocol configuration
  ip_protocol = "tcp"

  # Target port mapping constraints
  from_port = var.container_port
  to_port   = var.container_port

  # Explicitly scopes down target interface destination to just the Task SG
  referenced_security_group_id = aws_security_group.task.id
}

# acts as the security shield for our containers
resource "aws_security_group" "task" {
  name        = "${var.project}-${var.environment}-task-sg"
  description = "Isolates ECS tasks to only accept routed traffic from the ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-task-sg"
  }
}

# guarantees the app port only accepts incoming traffic
resource "aws_vpc_security_group_ingress_rule" "task_container" {
  security_group_id = aws_security_group.task.id
  description       = "Allow application traffic strictly from the ALB security group"
  from_port         = var.container_port
  ip_protocol       = "tcp"
  to_port           = var.container_port

  # Protects public IP tasks by explicitly tracking the ALB security group context
  referenced_security_group_id = aws_security_group.alb.id
}

#  gives the containers a clear path out to the internet to fetch system dependencies/pull software images.
resource "aws_vpc_security_group_egress_rule" "task_all" {
  security_group_id = aws_security_group.task.id
  description       = "Allow tasks outbound routing to pull images or reach external APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# AWS Application Load Balancer Infrastructure
# ===

# This provisions our public-facing application load balancer 
# to catch  web traffic and spread it across the subnets
resource "aws_lb" "api" {
  name               = "${var.project}-${var.environment}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

# keeps track of our running application instances
resource "aws_lb_target_group" "api" {
  name        = "${var.project}-${var.environment}-tg"
  target_type = "ip" # required for AWS fargate tasks
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  # Accelerated connection termination optimization for deployment/demo cycles
  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "HTTP"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-${var.environment}-tg"
  }
}

# catches unencrypted HTTP web traffic on port 80 and forces a secure 301 redirect over to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

  redirect {
    port = "443"
    protocol = "HTTPS"
    status_code = "HTTP_301"
  }
  }
}

# hosts the secure SSL/TLS gateway on port 443
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# adjusts the public-facing firewall rules to allow secure HTTPS
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  description       = "Allow public Internet traffic over HTTPS"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.alb.id
}