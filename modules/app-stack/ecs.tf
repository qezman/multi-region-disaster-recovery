# AWS ECS Fargate & CloudWatch Logging Layer
#===

# creates a centralized log bucket to securely view app container's console output
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "${var.project}-${var.environment}-ecs"
  retention_in_days = 7

  tags = {
    Name = "${var.project}-${var.environment}-ecs"
  }
}

# This sets up container cluster workspace where all of the Fargate tasks will be grouped
resource "aws_ecs_cluster" "api" {
  name = "${var.project}-${var.environment}-cluster"

  tags = {
    Name = "${var.project}-${var.environment}-cluster"
  }
}

# provisions the background IAM role that AWS uses to pull Docker images from ECR and stream logs to CloudWatch.
resource "aws_iam_role" "execution" {
  name = "${var.project}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-${var.environment}-ecs-execution-role"
  }
}

# securely fastens the AWS-managed execution policy directly onto the worker role
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# This defines the app's structural blueprint, specifying computing limits, operating systems, and target image locations
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project}-${var.environment}-task"
  network_mode             = "awsvpc" #required for ECS fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION_NAME"
          value = var.region_name
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.region_name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project}-${var.environment}-task"
  }
}

# This spins up the long-running background service that
# manages the containers and plugs them into the LB
resource "aws_ecs_service" "api" {
  name                              = "${var.project}-${var.environment}-service"
  cluster                           = aws_ecs_cluster.api.id
  task_definition                   = aws_ecs_task_definition.api.arn
  launch_type                       = "FARGATE"
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true # required since tasks reside inside public network subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  # Resolves a critical race condition: ensures the ALB listener is ready before containers try to register
  depends_on = [aws_lb_listener.https]

  tags = {
    Name = "${var.project}-${var.environment}-service"
  }
}