# Amazon ECR Repository Configuration
resource "aws_ecr_repository" "api" {
  name                 = "${var.project}-api"
  image_tag_mutability = "IMMUTABLE"

  # allows Terraform to clean up the repository even if it still contains images.
  #   Never enable force_delete = true in a production
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "${var.project}-api"
  }
}

# Amazon ECR Repository Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  # Dynamically formats cleanup ruleset into a valid AWS JSON policy string
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the last 10 container images to optimize storage costs"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]

  })

}