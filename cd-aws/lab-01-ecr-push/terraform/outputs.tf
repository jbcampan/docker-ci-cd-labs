output "ecr_repository_url" {
  description = "Full URI of the ECR repository — use this in the GitHub Actions workflow"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role to set as the GitHub Actions secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_ecr_push.arn
}

output "aws_account_id" {
  description = "AWS account ID (used to build ECR registry URL)"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used"
  value       = var.aws_region
}