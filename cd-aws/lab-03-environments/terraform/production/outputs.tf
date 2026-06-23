# ---------------------------------------------------------------------------
# Outputs — copy these into the "production" GitHub Environment secrets
# (Settings → Environments → production → Environment secrets).
# ---------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "ECS cluster name — set as ECS_CLUSTER secret in the production GitHub Environment"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name — set as ECS_SERVICE secret in the production GitHub Environment"
  value       = aws_ecs_service.app.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions via OIDC — set as AWS_ROLE_ARN secret in the production GitHub Environment"
  value       = aws_iam_role.github_actions.arn
}

output "alb_dns_name" {
  description = "ALB public URL — open in browser to reach the production app"
  value       = "http://${aws_lb.main.dns_name}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group receiving container stdout/stderr"
  value       = aws_cloudwatch_log_group.app.name
}

output "task_definition_family" {
  description = "ECS task definition family name"
  value       = aws_ecs_task_definition.app.family
}

output "ecr_repository_uri" {
  description = "Shared ECR repository URI — same value as staging; set as ECR_URI secret in BOTH GitHub Environments"
  value       = data.terraform_remote_state.shared.outputs.ecr_repository_uri
}
