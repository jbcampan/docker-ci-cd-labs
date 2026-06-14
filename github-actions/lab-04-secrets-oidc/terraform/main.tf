terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider
#
# GitHub exposes a standard OIDC endpoint. AWS needs to trust it once per
# account. The thumbprint is the SHA-1 fingerprint of the root CA that signs
# GitHub's OIDC certificate - AWS uses it to verify the token.
#
# Note: as of 2023 AWS also accepts the GitHub OIDC CA automatically when
# you use the official thumbprint listed below.  We keep it explicit here
# so Terraform manages the resource and its lifecycle.
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # Audience expected inside the JWT - matches what actions/configure-aws-credentials sends.
  client_id_list = ["sts.amazonaws.com"]

  # SHA-1 thumbprint of the root CA for token.actions.githubusercontent.com
  # Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---------------------------------------------------------------------------
# Trust policy — who can assume this role?
#
# The condition is the critical security gate.
# sub format: repo:<org>/<repo>:environment:<env>
#
# This means: ONLY a job running inside the "staging" environment of THIS
# specific repository can call sts:AssumeRoleWithWebIdentity.
# Any other GitHub repo, branch or environment -> denied.
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
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # Pattern: repo:<org>/<repo>:environment:<env>
      values = [
        "repo:${var.github_org}/${var.github_repo}:environment:${var.github_environment}"
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# IAM role assumed by GitHub Actions
# ---------------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  # Credentials delivered by STS are valid for 1 hour (3600 s).
  # Increase only if your jobs routinely take longer.
  max_session_duration = 3600

  tags = {
    ManagedBy   = "terraform"
    Purpose     = "github-actions-oidc"
    Environment = var.github_environment
    Lab         = "lab-04-secrets-oidc"
  }
}

# ---------------------------------------------------------------------------
# Permissions granted to the role
#
# For this lab we grant read-only access to STS (GetCallerIdentity) so the
# workflow can verify the assumed identity. No write permissions needed here.
#
# In subsequent labs (cd-aws/) you will attach ECR push + ECS deploy policies.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid    = "AllowGetCallerIdentity"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_inline" {
  name   = "github-actions-sts-verify"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
