variable "github_org" {
  description = "GitHub organisation or username (e.g. my-org or john-doe)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. docker-cicd-labs)"
  type        = string
}

variable "github_environment" {
  description = "GitHub Actions environment that is allowed to assume the role"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region used for the provider"
  type        = string
  default     = "eu-west-3"
}

variable "role_name" {
  description = "Name of the IAM role created for GitHub Actions OIDC"
  type        = string
  default     = "github-actions-oidc-role"
}
