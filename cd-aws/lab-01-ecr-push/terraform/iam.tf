# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint fetched dynamically from GitHub's TLS cert
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Project   = "docker-ci-cd-labs"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Trust policy - who can assume this role?
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "github_trust" {
  statement {
    sid     = "GitHubOIDCTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Pattern: repo:<org>/<repo>:environment:<env>
      values = [
        "repo:${var.github_org}/${var.github_repo}:*"
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# IAM role assumed by GitHub Actions
# ---------------------------------------------------------------------------
resource "aws_iam_role" "github_ecr_push" {
  name               = "github-actions-ecr-push-${var.ecr_repo_name}"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  # Credentials delivered by STS are valid for 1 hour (3600 s).
  # Increase only if your jobs routinely take longer.
  max_session_duration = 3600

  tags = {
    Project   = "docker-ci-cd-labs"
    Lab       = "cd-aws-lab-01"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Permissions granted to the role
# ---------------------------------------------------------------------------
# - IAM Policy - least privilege ECR push 

resource "aws_iam_policy" "ecr_push" {
  name        = "ecr-push-${var.ecr_repo_name}"
  description = "Minimal permissions to push images to a single ECR repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRGetToken"
        Effect = "Allow"
        # GetAuthorizationToken is account-scoped, not resource-scoped
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPushImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        # Scoped to the single repository, not all of ECR
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_ecr_push.name
  policy_arn = aws_iam_policy.ecr_push.arn
}