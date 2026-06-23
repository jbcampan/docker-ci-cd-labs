# ---------------------------------------------------------------------------
# Remote state — isolated from `production` and `shared` by `key`.
# A `terraform destroy` run here can NEVER touch production's state, because
# they are two entirely separate state files (and, ideally, you'd also use
# two separate AWS accounts — see README "Going further").
# ---------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket         = "tfstate-yourname-docker-cicd-labs"
    key            = "cd-aws/lab-03-environments/staging/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "tfstate-yourname-docker-cicd-labs-lock"
    encrypt        = true
  }
}
