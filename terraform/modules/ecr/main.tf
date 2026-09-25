resource "aws_ecr_repository" "this" {
  name = var.name

  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Drop untagged layers/manifests after a day"
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep the last ${var.keep_last} versions"
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = var.keep_last
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}