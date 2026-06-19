variable "aws_region" {
  description = "AWS region where all resources are deployed."
  type        = string
  default     = "eu-west-3"
}

variable "project" {
  description = "Short project identifier used as a prefix for all resource names."
  type        = string
  default     = "ecs-lab02"
}

variable "environment" {
  description = "Deployment environment tag (e.g. lab, staging, production)."
  type        = string
  default     = "lab"
}

variable "app_version" {
  description = "Initial image tag to embed in the first task definition revision."
  type        = string
  default     = "latest"
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for the dedicated lab VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for two public subnets (must be in different AZs)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Fargate task sizing
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
  description = "GitHub repository in owner/repo format (used to scope the OIDC trust policy)."
  type        = string
  # example: "my-org/docker-cicd-labs"
}
