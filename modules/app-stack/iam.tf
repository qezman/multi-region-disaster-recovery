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

resource "aws_iam_role_policy" "read_database_secret" {
    count = var.enable_database_secret ? 1 : 0

    name = "${var.project}-${var.environment}-ecs-secret-read"
    role = aws_iam_role.execution.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.database_secret_arn
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = var.secret_kms_key_arn
      }
    ]
    })
}