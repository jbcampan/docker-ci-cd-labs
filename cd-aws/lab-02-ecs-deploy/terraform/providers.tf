terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote state — uncomment after creating your S3 bucket + DynamoDB table.
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "<your-tfstate-bucket>"
  #   key            = "cd-aws/lab-02-ecs-deploy/terraform.tfstate"
  #   region         = "eu-west-3"
  #   dynamodb_table = "<your-lock-table>"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Lab         = "cd-aws-lab-02"
    }
  }
}
