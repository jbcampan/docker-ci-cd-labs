variable "aws_region" {
  description = "AWS region where all resources are deployed"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Prefix applied to every resource name (e.g. myapp, docker-labs)"
  type        = string
  default     = "docker-cicd-labs"
}

variable "github_repo" {
  description = "Full GitHub repo path used in the OIDC sub condition, e.g. octocat/my-repo"
  type        = string
  # Set via TF_VAR_github_repo or terraform.tfvars — never hard-code here
}

variable "db_connection_string" {
  description = "Initial database connection string stored in Secrets Manager"
  type        = string
  sensitive   = true
  # Example: postgresql://user:password@db.example.com:5432/mydb
}

variable "third_party_api_key" {
  description = "Initial third-party API key stored in Secrets Manager"
  type        = string
  sensitive   = true
}
