variable "aws_region" {
  description = "AWS region where the ECR repository will be created"
  type        = string
  default     = "eu-west-3"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "cd-aws-lab-01"
}

variable "github_org" {
  description = "GitHub organisation or username (e.g. 'myorg' in github.com/myorg/repo)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. 'docker-cicd-labs')"
  type        = string
}