terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "ecs-lab03"
      ManagedBy = "terraform"
      Lab       = "cd-aws-lab-03"
      Scope     = "shared"
    }
  }
}
