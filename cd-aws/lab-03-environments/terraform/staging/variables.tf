variable "aws_region" {
  description = "AWS region where this environment's resources are deployed."
  type        = string
  default     = "eu-west-3"
}

variable "project" {
  description = "Short project identifier used as a prefix for all resource names in this environment. Must be unique per environment (e.g. ecs-lab03-staging vs ecs-lab03-production) so resources never collide."
  type        = string
  default     = "ecs-lab03-staging"
}

variable "environment" {
  description = "Deployment environment name. Drives the ENVIRONMENT env var inside the container and the GitHub OIDC trust condition."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be exactly \"staging\" or \"production\" — this value is used to scope the GitHub OIDC trust policy to the matching GitHub Environment."
  }
}

variable "app_version" {
  description = "Initial image tag to embed in the first task definition revision (bootstrap only — the pipeline manages subsequent revisions)."
  type        = string
  default     = "latest"
}

# ---------------------------------------------------------------------------
# Shared state reference
# ---------------------------------------------------------------------------
variable "tfstate_bucket" {
  description = "S3 bucket holding the shared module's state (same bucket as this environment's own backend, different key)."
  type        = string
  # example: "tfstate-yourname-docker-cicd-labs"
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for this environment's dedicated VPC. Must differ from the other environment's CIDR if you ever peer them — not required here, but good habit."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for two public subnets (must be in different AZs)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Fargate task sizing — identical across environments on purpose for this lab
# (see README: "same image, same infra shape, only variables change").
variable "task_cpu" {
  description = "CPU units for the Fargate task (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory (MiB) for the Fargate task."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of running task copies in the ECS service."
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port exposed by the container (must match Dockerfile EXPOSE)."
  type        = number
  default     = 5000
}

# Health check
variable "health_check_path" {
  description = "ALB target group health-check path."
  type        = string
  default     = "/health"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (used to scope the OIDC trust policy to this exact repo)."
  type        = string
  # example: "my-org/docker-cicd-labs"
}
