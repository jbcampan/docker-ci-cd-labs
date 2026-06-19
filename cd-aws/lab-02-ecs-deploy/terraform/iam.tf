# ---------------------------------------------------------------------------
# Shared assume-role policy for ECS roles
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# ECS Execution Role
# ---------------------------------------------------------------------------
# Used by the ECS *agent* (not by your application code) to bootstrap a task:
#   - Pull the Docker image from ECR
#   - Write container stdout/stderr to CloudWatch Logs
#   - Read secrets from Secrets Manager / SSM Parameter Store (if configured)
#
# Think of it as: "what AWS permissions does ECS need to *start* my task?"
# ---------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  name               = "${var.project}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  description        = "ECS execution role: ECR pull + CloudWatch Logs"
}

resource "aws_iam_role_policy_attachment" "execution_ecr_logs" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# ECS Task Role
# ---------------------------------------------------------------------------
# Used by the *application code running inside the container* at runtime.
# Add policies here when your app needs to call other AWS services (S3,
# DynamoDB, SQS, etc.).  Keeping it separate from the execution role follows
# the principle of least privilege: a compromised container cannot pull ECR
# images or write CloudWatch logs on your behalf.
#
# Think of it as: "what AWS permissions does my app need while it's running?"
# ---------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name               = "${var.project}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  description        = "ECS task role: runtime permissions for the application"
}

# Uncomment to grant the app read access to S3:
# resource "aws_iam_role_policy_attachment" "task_s3" {
#   role       = aws_iam_role.task.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }

# ---------------------------------------------------------------------------
# GitHub Actions OIDC — keyless authentication
# ---------------------------------------------------------------------------
# Instead of storing long-lived IAM access keys as GitHub secrets (which must
# be rotated and can leak), we use OpenID Connect (OIDC):
#
#   1. GitHub generates a short-lived JWT token for each workflow run.
#   2. AWS verifies the token against the GitHub OIDC provider.
#   3. AWS issues temporary STS credentials scoped to this IAM role.
#
# No static credentials ever touch GitHub. The token is valid only for the
# duration of the workflow run and is bound to a specific repo/branch.
# ---------------------------------------------------------------------------

# Fetch the OIDC thumbprint that AWS uses to verify GitHub's TLS certificate.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# Register GitHub as a trusted OIDC identity provider in this AWS account.
# Only needs to exist once per account — Terraform will no-op if it already
# exists (the resource uses the URL as its unique key).
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# IAM role that the GitHub Actions workflow assumes via OIDC.
resource "aws_iam_role" "github_actions" {
  name        = "${var.project}-github-actions-role"
  description = "Assumed by GitHub Actions via OIDC - no static credentials"

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
            # Restrict to your repository only — replace with your GitHub org/repo.
            # Format: "repo:<owner>/<repo>:ref:refs/heads/<branch>"
            # Using "ref:refs/heads/main" locks it to the main branch.
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Wildcards are intentional: allows any branch/tag in your repo.
            # Tighten to "repo:${var.github_repo}:ref:refs/heads/main" for prod.
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# Permissions granted to the GitHub Actions role.
# Scope: only what the CD pipeline actually needs.
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
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
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/${var.project}-app"
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
        ]
        Resource = "*"
      },
      {
        Sid      = "PassRolesToECS"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [
          aws_iam_role.execution.arn,
          aws_iam_role.task.arn,
        ]
      },
      {
        Sid    = "ALBDescribe"
        Effect = "Allow"
        Action = ["elasticloadbalancing:DescribeLoadBalancers"]
        Resource = "*"
      },
    ]
  })
}
