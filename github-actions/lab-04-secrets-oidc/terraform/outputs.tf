output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider (created once per AWS account)"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role — paste this as the AWS_ROLE_ARN secret in your GitHub environment"
  value       = aws_iam_role.github_actions.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.github_actions.name
}

output "trust_policy_subject" {
  description = "The exact OIDC subject (sub) that can assume this role"
  value       = "repo:${var.github_org}/${var.github_repo}:environment:${var.github_environment}"
}
