# ---------------------------------------------------------------------------
# Remote state — this module's state lives at its own key in the shared
# bootstrap bucket. Fill in `bucket` and `dynamodb_table` with the outputs
# from `terraform/bootstrap` (see README step 0).
# ---------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket         = "tfstate-yourname-docker-cicd-labs"
    key            = "cd-aws/lab-03-environments/shared/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "tfstate-yourname-docker-cicd-labs-lock"
    encrypt        = true
  }
}
