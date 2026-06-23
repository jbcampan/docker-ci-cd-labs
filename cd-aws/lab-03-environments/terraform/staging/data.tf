# ---------------------------------------------------------------------------
# Read the shared module's state to get the ECR repository URI/ARN.
#
# This is how Terraform references resources managed by a DIFFERENT state
# file: `terraform_remote_state` reads the shared module's outputs as plain
# data, without taking ownership of those resources. The shared ECR repo is
# created once (terraform/shared) and consumed read-only here.
# ---------------------------------------------------------------------------
data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "cd-aws/lab-03-environments/shared/terraform.tfstate"
    region = var.aws_region
  }
}
