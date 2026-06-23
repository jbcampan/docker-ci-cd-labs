# ---------------------------------------------------------------------------
# Bootstrap — remote state backend (S3 + DynamoDB lock table)
#
# This module is applied ONCE, manually, BEFORE anything else in this lab.
# It is intentionally isolated from the staging / production / shared
# modules: the bucket that stores Terraform state cannot itself be managed
# by the state it stores (chicken-and-egg problem). This module therefore
# uses a *local* state file (default backend) — only this one.
#
# Run this only once per AWS account/region. If the bucket already exists
# from a previous lab, skip this module entirely and reuse it (just point
# the `key` in other modules' backend blocks to a new prefix).
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No backend block here on purpose — this module's own state stays local.
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "eu-west-3"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
  # example: "tfstate-yourname-docker-cicd-labs"
}

# ---------------------------------------------------------------------------
# S3 bucket — stores the .tfstate files for shared / staging / production
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = var.bucket_name

  # Prevents accidental deletion via `terraform destroy` run from this module.
  # You must remove this manually before destroying the bucket on purpose.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = var.bucket_name
    Purpose   = "terraform-remote-state"
    ManagedBy = "terraform-bootstrap"
  }
}

# Versioning lets you recover a previous state file if something corrupts it
# (e.g. a bad `terraform apply` or a manual edit gone wrong).
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# State files can contain sensitive values (ARNs, sometimes secrets if
# misused) — encrypt at rest by default.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — state files should never be reachable from the
# internet.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB table — state locking
#
# Without this, two people (or two CI runs) applying Terraform at the same
# time could corrupt the state file. Terraform acquires a lock row in this
# table before any apply/plan that touches state, and releases it after.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${var.bucket_name}-lock"
  billing_mode = "PAY_PER_REQUEST" # no fixed cost — pay only per lock operation
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "${var.bucket_name}-lock"
    Purpose   = "terraform-state-locking"
    ManagedBy = "terraform-bootstrap"
  }
}

output "bucket_name" {
  description = "S3 bucket name — use this in the `bucket` field of every backend.tf in this lab."
  value       = aws_s3_bucket.tfstate.id
}

output "dynamodb_table_name" {
  description = "DynamoDB lock table name — use this in the `dynamodb_table` field of every backend.tf in this lab."
  value       = aws_dynamodb_table.tfstate_lock.name
}
