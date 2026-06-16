# ── ECR Repository ────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE" # allows overwriting 'latest'

  image_scanning_configuration {
    scan_on_push = true # free basic scanning on every push
  }

  tags = {
    Project     = "docker-cicd-labs"
    Lab         = "cd-aws-lab-01"
    ManagedBy   = "terraform"
  }
}

# ── ECR Lifecycle Policy ──────────────────────────────────────────────────────
# Keep last 10 tagged images; purge untagged images after 7 days

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}