variable "aws_region" {
  description = "AWS region where the shared ECR repository lives."
  type        = string
  default     = "eu-west-3"
}

variable "project" {
  description = "Short project identifier shared across staging and production."
  type        = string
  default     = "ecs-lab03"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format — used to scope the OIDC push role trust policy."
  type        = string
  # example: "my-org/docker-cicd-labs"
}
