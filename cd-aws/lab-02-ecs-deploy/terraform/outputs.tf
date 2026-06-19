# ---------------------------------------------------------------------------
# Outputs — copy these values into GitHub Actions secrets after `terraform apply`
# ---------------------------------------------------------------------------

output "ecr_repository_uri" {
  description = "Full ECR repository URI — set as ECR_URI secret in GitHub Actions"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name — set as ECS_CLUSTER secret in GitHub Actions"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name — set as ECS_SERVICE secret in GitHub Actions"
  value       = aws_ecs_service.app.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions via OIDC — set as AWS_ROLE secret"
  value       = aws_iam_role.github_actions.arn
}

output "alb_dns_name" {
  description = "ALB public URL — open in browser to reach the deployed app"
  value       = "http://${aws_lb.main.dns_name}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group receiving container stdout/stderr"
  value       = aws_cloudwatch_log_group.app.name
}

output "task_definition_family" {
  description = "ECS task definition family name — used in task-definition.json"
  value       = aws_ecs_task_definition.app.family
}
