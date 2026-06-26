# ---------------------------------------------------------------------------
# IAM OIDC role for GitHub Actions (main branch only)
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

resource "aws_iam_role" "github_actions_oidc" {
  name        = "${var.project_name}-github-actions-oidc"
  description = "Assumed by GitHub Actions via OIDC - restricted to main branch of ${var.github_repo}"

  # Trust policy: only tokens issued for the main branch of our repo are accepted.
  # The condition on token.actions.githubusercontent.com:sub uses the pattern
  #   repo:<owner>/<repo>:ref:refs/heads/<branch>
  # A PR token has sub = repo:<owner>/<repo>:pull_request  → denied.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Restrict to: exact repo AND main branch only
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# Least-privilege policy: GetSecretValue on our specific secret ARN only
resource "aws_iam_role_policy" "github_actions_secrets" {
  name = "read-app-secret"
  role = aws_iam_role.github_actions_oidc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadAppSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Explicit ARN — never use Resource: "*"
        Resource = aws_secretsmanager_secret.app_secret.arn
      }
    ]
  })
}


# ---------------------------------------------------------------------------
# Automatic rotation — Lambda function
# ---------------------------------------------------------------------------

# IAM role for the rotation Lambda
resource "aws_iam_role" "rotation_lambda" {
  name = "${var.project_name}-secret-rotation-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "rotation_lambda_secrets" {
  name = "allow-secret-rotation"
  role = aws_iam_role.rotation_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRotation"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.app_secret.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}