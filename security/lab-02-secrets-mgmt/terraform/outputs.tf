output "secret_arn" {
  description = "ARN of the Secrets Manager secret — used in the GitHub Actions workflow"
  value       = aws_secretsmanager_secret.app_secret.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.app_secret.name
}

output "oidc_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC — copy into the workflow"
  value       = aws_iam_role.github_actions_oidc.arn
}

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function"
  value       = aws_lambda_function.secret_rotation.arn
}

output "rotation_lambda_name" {
  description = "Name of the rotation Lambda function"
  value       = aws_lambda_function.secret_rotation.function_name
}
