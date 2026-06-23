# ---------------------------------------------------------------------------
# ECR repository — SHARED between staging and production.
#
# This is the central point of this lab: staging and production deploy the
# EXACT SAME image (same digest, identified by the commit SHA tag). Only the
# environment-specific Terraform variables (cluster name, task def, ALB)
# differ. If staging and production had separate ECR repos, you could end up
# rebuilding the image differently for each — defeating the purpose of
# "what passed staging is exactly what reaches production".
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "${var.project}-app"
  image_tag_mutability = "MUTABLE" # allows re-tagging "latest"

  image_scanning_configuration {
    scan_on_push = true # free basic scan for known CVEs
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the 20 most recent tagged images (staging + production share this repo, so keep more history than lab-02)"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "ecr_repository_uri" {
  description = "Full ECR repository URI - same value used by both staging and production GitHub environments as the ECR_URI secret."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name - needed to empty the repo before `terraform destroy`."
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_arn" {
  description = "ECR repository ARN - referenced by both environments' IAM policies to scope ECR push permissions."
  value       = aws_ecr_repository.app.arn
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC role for the BUILD job only.
#
# This role exists so the `build-and-push` job — which intentionally has NO
# `environment:` key, because building the image happens before any
# environment-specific approval gate — does not need either the staging or
# production deploy role. It can ONLY push to ECR; it has zero ECS
# permissions, so even if this role's credentials leaked, the attacker could
# push a malicious image but could not deploy it anywhere or touch any
# running service.
#
# Trust policy: matches on repo + ref:refs/heads/main (no `environment:`
# claim exists for this job, since it doesn't declare one).
# ---------------------------------------------------------------------------
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_actions_push" {
  name        = "${var.project}-github-actions-push-role"
  description = "Assumed by the build-and-push job only - ECR push rights, no ECS rights at all"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_push" {
  name = "${var.project}-github-actions-push-policy"
  role = aws_iam_role.github_actions_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}

output "github_actions_push_role_arn" {
  description = "IAM role ARN for the build-and-push job - set as the repo-level secret AWS_ROLE_ARN_PUSH (Settings → Secrets and variables → Actions → Repository secrets, NOT an Environment secret)."
  value       = aws_iam_role.github_actions_push.arn
}

output "github_oidc_provider_arn" {
  description = "The AWS-account GitHub OIDC provider ARN, created here in the shared module. Both staging and production read this value via terraform_remote_state to build their IAM role trust policies."
  value       = aws_iam_openid_connect_provider.github.arn
}
