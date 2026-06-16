# Lab cd-aws-01 — ECR + Automatic Push

[![CD — ECR Push](https://github.com/jbcampan/docker-ci-cd-labs/actions/workflows/cd-aws-lab-01.yml/badge.svg)](https://github.com/jbcampan/docker-ci-cd-labs/actions/workflows/cd-aws-lab-01.yml)

---

## Objective

Create a private ECR registry via Terraform and configure GitHub Actions to
automatically push a Docker image after every successful CI build.
This is the first half of a complete CD pipeline — the second half (deploying to
ECS Fargate) is covered in the next lab.

---

## Structure

```
docker-ci-cd-labs/
├── .github/
│   └── workflows/
│       └── cd-aws-lab-01.yml              # CI/CD pipeline (must live at repo root)
└── cd-aws/
    └── lab-01-ecr-push/
        ├── README.md                      # this file
        ├── app/
        │   ├── main.py                    # minimal FastAPI app (2 routes)
        │   ├── requirements.txt           # runtime + test dependencies
        │   └── test_main.py               # pytest suite via TestClient
        ├── Dockerfile                     # multi-stage: builder → runner (non-root)
        ├── .dockerignore                  # excludes tests, .terraform, *.tfstate
        └── terraform/
            ├── providers.tf               # terraform block + AWS provider
            ├── data.tf                    # aws_caller_identity + tls_certificate
            ├── ecr.tf                     # ECR repository + lifecycle policy
            ├── iam.tf                     # OIDC provider + IAM role + policy
            ├── variables.tf               # aws_region, ecr_repo_name, github_org/repo
            ├── outputs.tf                 # ecr_repository_url, iam_role_arn
            └── terraform.tfvars.example   # template — copy to terraform.tfvars (gitignored)
```

---

## What you create

| Resource | Description |
|---|---|
| `aws_ecr_repository` | Private registry with image scanning enabled on push |
| `aws_ecr_lifecycle_policy` | Removes untagged images after 7 days; keeps the last 10 tagged images |
| `aws_iam_openid_connect_provider` | OIDC trust between AWS and GitHub Actions |
| `aws_iam_role` | Role assumed by GitHub via OIDC — no long-lived credentials |
| `aws_iam_policy` | Minimal ECR permissions: `GetAuthorizationToken` + push to this repo only |
| GitHub Actions workflow | test → build → ECR login → push `sha-<short>` + `latest` |

---

## What you learn

| Concept | Explanation |
|---|---|
| **ECR vs GHCR** | ECR is private by default and natively integrated with ECS/Fargate and IAM. GHCR is public-friendly and tied to GitHub's ecosystem. For CD pipelines targeting AWS, ECR is the natural choice. |
| **ECR lifecycle policies** | Without a policy, the registry grows indefinitely. This policy removes untagged images after 7 days and caps tagged images at 10. Avoided cost ≈ $0.10/GB/month. |
| **ECR login in CI** | `aws ecr get-login-password` returns a short-lived token (valid 12 h) piped directly to `docker login`. Unlike Docker Hub, there is no permanent username/password — the token is issued by IAM on the fly. |
| **OIDC vs static keys** | GitHub mints a signed JWT from its identity provider. AWS verifies the signature and issues a temporary credential. Zero long-lived secrets stored in GitHub. |
| **Least privilege in CI** | The IAM role has exactly 6 ECR actions scoped to a single repository ARN. It cannot read other repos, manage EC2 instances, or access S3. |
| **Multi-label tagging** | `sha-<commit>` provides traceability (which commit produced which image). `latest` provides convenience (pull without knowing the SHA). Both are complementary; in production, always deploy on the SHA tag, never on `latest`. |
| **Multi-stage Dockerfile** | The `builder` stage installs packages into a prefix directory. The `runner` stage copies only that prefix. The final image never contains the build toolchain. |

---

## Estimated cost

| Resource | Cost |
|---|---|
| ECR storage | $0.10 / GB / month (a slim FastAPI image ≈ 50 MB → ~$0.005/month) |
| ECR outbound transfer | $0.09 / GB (negligible at lab scale) |
| IAM / OIDC | Free |
| **Lab total** | **< $0.01 / month** — run `terraform destroy` when done |

> ⚠️ Images accumulate on every push. The lifecycle policy handles automatic
> cleanup, but `terraform destroy` is the cleanest way to remove everything at
> the end of the lab.

---

## Prerequisites

- [ ] AWS CLI configured (`aws configure` or environment variables)
- [ ] Terraform >= 1.6 installed
- [ ] Docker installed and running
- [ ] GitHub repository with Actions enabled
- [ ] Sufficient AWS permissions to create IAM and ECR resources

---

## Steps

### 1. Provision infrastructure with Terraform

```bash
# Navigate to the terraform directory
cd cd-aws/lab-01-ecr-push/terraform

# Copy the example vars file and fill in your values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set github_org and github_repo

# Download providers
terraform init

# Review the plan
terraform plan

# Apply — creates ECR + OIDC provider + IAM role and policy
terraform apply
```

### 2. Copy Terraform outputs to GitHub secrets

```bash
# Display outputs
terraform output

# Example output:
#   ecr_repository_url = "123456789.dkr.ecr.eu-west-3.amazonaws.com/cd-aws-lab-01"
#   iam_role_arn       = "arn:aws:iam::123456789:role/github-actions-ecr-push-cd-aws-lab-01"
```

In GitHub → **Settings → Secrets and variables → Actions**, create:

| Secret name | Value |
|---|---|
| `AWS_ROLE_ARN` | value of `iam_role_arn` from `terraform output` |

### 3. Verify locally (optional)

```bash
cd cd-aws/lab-01-ecr-push

# Run tests
pip install -r app/requirements.txt
pytest app/test_main.py -v

# Build the image locally
docker build -t cd-aws-lab-01:local .

# Smoke-test the container
docker run --rm -p 8000:8000 cd-aws-lab-01:local
curl http://localhost:8000/health
# → {"status":"healthy"}
```

### 4. Trigger the pipeline

```bash
# From the repository root
git add .
git commit -m "feat(cd-aws): add lab-01 ECR push pipeline"
git push origin main
# → The cd-aws-lab-01 workflow triggers automatically
```

### 5. Verify in AWS

```bash
# List images in the repository
aws ecr list-images \
  --repository-name cd-aws-lab-01 \
  --region eu-west-3

# Expected: two entries — sha-<shortsha> and latest
```

### 6. Cleanup

```bash
# Delete all images first (ECR refuses to destroy a non-empty repo without force_delete)
aws ecr batch-delete-image \
  --repository-name cd-aws-lab-01 \
  --region eu-west-3 \
  --image-ids "$(aws ecr list-images \
      --repository-name cd-aws-lab-01 \
      --region eu-west-3 \
      --query 'imageIds' \
      --output json)"

# Destroy all Terraform-managed resources
cd cd-aws/lab-01-ecr-push/terraform
terraform destroy
```

---

## Understanding checks

**Why does `GetAuthorizationToken` have `Resource: "*"`?**
This action returns a token scoped to your ECR account registry, not to a specific
repository. AWS does not accept a repository ARN for this action — it is a service
constraint, not a lack of rigor in the policy.

**Why `image_tag_mutability = "MUTABLE"`?**
To allow overwriting the `latest` tag on every push. With `IMMUTABLE`, each tag
can only be written once — useful in production for strict traceability, but
impractical in a lab where you push frequently.

**Why two tags (`sha-<commit>` and `latest`)?**
`sha-<commit>` is effectively immutable (the SHA never changes). It lets you trace
exactly which image came from which commit. `latest` is a convenience for
`docker pull` without specifying a SHA. In production, always deploy on the SHA
tag — `latest` is for humans, not for deployment automation.

**What happens if tests fail?**
The `push-to-ecr` job depends on `test` via `needs: test`. If `pytest` exits with
a non-zero code, GitHub Actions cancels the push job. The image is never built or
sent to ECR.

**Dockerfile — possible improvement**
The current `requirements.txt` includes both runtime packages (`fastapi`, `uvicorn`)
and test packages (`pytest`, `httpx`). Both end up in the final image via the
`builder` stage. To keep the image lean, split into two files:

```
requirements.txt      # fastapi, uvicorn — copied into the image
requirements-dev.txt  # pytest, httpx    # installed in CI only, never in the image
```

In the workflow, install both for the test job; use only `requirements.txt` in the
`Dockerfile`. This is a best practice worth applying in the next lab.

---

## Useful links

- [ECR User Guide — Lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)
- [GitHub Actions — Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [aws-actions/amazon-ecr-login](https://github.com/aws-actions/amazon-ecr-login)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform aws_ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)
- [ECR pricing](https://aws.amazon.com/ecr/pricing/)