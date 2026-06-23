# ---------------------------------------------------------------------------
# Remote state — different `key` from staging. Even though both states may
# live in the same S3 bucket, they are two entirely separate state files.
# A `terraform destroy` run from the staging directory has zero ability to
# affect anything tracked in this state, and vice versa.
# ---------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket         = "tfstate-yourname-docker-cicd-labs"
    key            = "cd-aws/lab-03-environments/production/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "tfstate-yourname-docker-cicd-labs-lock"
    encrypt        = true
  }
}
