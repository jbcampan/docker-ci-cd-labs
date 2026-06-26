# Lab 02 — Secret Management (OIDC + Secrets Manager)

## Objective

Implement a zero-static-secret architecture across the full CI/CD chain.
No long-lived AWS keys in code, no plaintext secrets in environment variables,
no secrets in GitHub Actions variables. Every credential is fetched at runtime
from AWS Secrets Manager, accessed through a time-limited OIDC token, and
rotated automatically every 30 days.

---

## Structure

```
docker-ci-cd-labs/
├── .github/
│   └── workflows/
│       └── security-lab-02.yml               # CI pipeline (must live at repo root)
└── security/
    └── lab-02-secrets-mgmt/
        ├── README.md
        ├── Dockerfile                         # Multi-stage Python 3.12 image
        ├── .dockerignore                      # Excludes terraform/, .env, state files
        ├── .env.example                       # Runtime config vars (no secret values)
        ├── app/
        │   ├── main.py                        # Fetches secrets via boto3 at startup
        │   └── requirements.txt               # boto3, botocore — pinned versions
        └── terraform/
            ├── main.tf                        # terraform{} block, provider, data sources
            ├── secretsmanager.tf              # Secret, initial version, rotation schedule
            ├── iam.tf                         # OIDC role (GitHub Actions) + Lambda role
            ├── lambda.tf                      # archive_file, aws_lambda_function, permission
            ├── variables.tf                   # All input variables declared
            ├── outputs.tf                     # ARNs exported for the workflow
            ├── terraform.tfvars.example       # Template — copy to terraform.tfvars
            └── lambda/
                └── rotation_lambda.py         # 4-step rotation protocol (stub)
```

---

## What you create

| Resource | Description |
|---|---|
| `aws_secretsmanager_secret` | Stores `db_connection_string` + `third_party_api_key` as a single JSON entry |
| `aws_secretsmanager_secret_rotation` | Triggers the rotation Lambda every 30 days |
| `aws_lambda_function` | Rotation stub — implements the 4-step Secrets Manager rotation protocol |
| `aws_iam_role` (OIDC) | Trusted only by `repo:<owner>/<repo>:ref:refs/heads/main` — PRs are blocked |
| `aws_iam_role_policy` | `GetSecretValue` on the explicit secret ARN only — no wildcard |
| Docker image | Python app that calls `secretsmanager.get_secret_value` at startup |
| GitHub Actions workflow | OIDC auth → fetch secret → mask → inject → run container |

---

## What you learn

| Concept | Explanation |
|---|---|
| **Three levels of secrets** | **GitHub Secrets** — CI configuration only, not rotated. **Container env vars** — runtime static, visible to any process in the container. **Secrets Manager** — rotated, audited, IAM-gated. Use the deepest level appropriate to each secret. |
| **OIDC sub conditions** | The `sub` claim in a GitHub OIDC token encodes the exact trigger context. `repo:org/repo:ref:refs/heads/main` only matches pushes to main. A PR token has `sub = repo:org/repo:pull_request` — the IAM `StringEquals` condition rejects it. |
| **Rotation lifecycle** | Secrets Manager calls the Lambda four times: `createSecret` → `setSecret` → `testSecret` → `finishSecret`. Each step is idempotent. Until `finishSecret`, `AWSCURRENT` is untouched. |
| **CloudTrail audit trail** | Every `GetSecretValue` call is logged: which role, from which IP, at what time. Filter in Event history by event name `GetSecretValue`. |
| **Least privilege on secrets** | The OIDC role policy uses `Resource: <exact ARN>` — never `Resource: "*"`. A compromised token can only read this one secret. |
| **ClientError in boto3** | `get_secret_value` raises `ClientError` if the secret does not exist or IAM permissions are insufficient — catching it explicitly gives an actionable error message instead of a cryptic traceback. |
| **::add-mask::** | GitHub Actions redacts any string registered with `::add-mask::` from all subsequent log lines. Used immediately after fetching the secret value. |

---

## Cost estimate

| Resource | Price | Lab cost |
|---|---|---|
| Secrets Manager secret | $0.40/secret/month | ~$0.40 (delete after) |
| Secrets Manager API calls | $0.05 per 10 000 calls | < $0.01 |
| Lambda invocations (rotation) | Free tier (1M/month) | $0.00 |
| CloudTrail | Free for management events | $0.00 |
| **Total** | | **< $0.50** |

> ⚠️ **Delete the secret when done:** `terraform destroy` enforces a 7-day recovery window
> (billing continues during that period). Use the CLI command in step 10 to bypass it.

---

## Prerequisites

- AWS account with the GitHub OIDC provider already configured
  (`https://token.actions.githubusercontent.com`) — created in the previous AWS track.
- Terraform >= 1.5 installed locally.
- Docker installed locally (for the optional local test in step 6).
- GitHub repository with Actions enabled.
- AWS CLI v2 configured with credentials that can create IAM roles, Lambda functions,
  and Secrets Manager secrets.

---

## Steps

### 1 — Clone and navigate

```bash
# From repo root
cd security/lab-02-secrets-mgmt
```

### 2 — Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit terraform.tfvars — fill in your GitHub repo, DB string, and API key
# terraform.tfvars is already listed in .gitignore
$EDITOR terraform/terraform.tfvars
```

### 3 — Provision AWS resources

```bash
cd terraform

# Download providers
terraform init

# Preview what will be created
terraform plan

# Create: Secrets Manager secret, rotation Lambda, OIDC IAM role
terraform apply

# Note the outputs — you will need them in steps 4 and 5
terraform output
```

Expected outputs:
```
oidc_role_arn       = "arn:aws:iam::<account>:role/docker-cicd-labs-github-actions-oidc"
secret_arn          = "arn:aws:secretsmanager:eu-west-3:<account>:secret/docker-cicd-labs/prod/app-credentials-XXXXXX"
secret_name         = "docker-cicd-labs/prod/app-credentials"
rotation_lambda_arn = "arn:aws:lambda:eu-west-3:<account>:function/docker-cicd-labs-secret-rotation"
```

### 4 — Add the OIDC role ARN to GitHub Secrets

```
GitHub → your repo → Settings → Secrets and variables → Actions → New repository secret

Name:  AWS_OIDC_ROLE_ARN
Value: <paste oidc_role_arn from terraform output>
```

> This is the only GitHub Secret in this lab — it stores the role **name** (not a credential).
> The actual credential material is generated at runtime by OIDC and expires in 1 hour.

### 5 — Copy the workflow file to its correct location

The workflow must live at `.github/workflows/` in the **repository root** to be picked up by GitHub Actions.

```bash
# From repo root
cp security/lab-02-secrets-mgmt/github-actions-workflow/security-lab-02.yml \
   .github/workflows/security-lab-02.yml
```

### 6 — (Optional) Test the Python app locally

```bash
cd security/lab-02-secrets-mgmt

# Run directly with a named AWS profile
APP_SECRET_NAME=docker-cicd-labs/prod/app-credentials \
AWS_REGION=eu-west-3 \
  python app/main.py

# Or in Docker
docker build -t secrets-demo:local .

docker run --rm \
  --env APP_SECRET_NAME=docker-cicd-labs/prod/app-credentials \
  --env AWS_REGION=eu-west-3 \
  --env AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id)" \
  --env AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key)" \
  secrets-demo:local
```

Expected output:
```
Credentials loaded: ['db_connection_string', 'third_party_api_key']
```

### 7 — Push to main and observe the pipeline

```bash
# From repo root
git add .github/workflows/security-lab-02.yml \
        security/lab-02-secrets-mgmt/
git commit -m "feat(security): add lab-02 OIDC + Secrets Manager demo"
git push origin main
```

Go to **GitHub → Actions → security-lab-02** and watch each step:
- Step 2 shows the assumed role ARN (not credentials)
- Step 4 (`fetch_secret`) outputs `"Secret fetched and masked successfully"` — the values are invisible
- Step 6 runs the container; secret values do not appear in logs

### 8 — Verify the audit trail in CloudTrail

```bash
# List the last 5 GetSecretValue events for your secret
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetSecretValue \
  --max-results 5 \
  --query 'Events[].{Time:EventTime, User:Username, Source:CloudTrailEvent}' \
  --output table
```

### 9 — Trigger a manual rotation (optional)

```bash
# Rotate immediately (does not wait for the 30-day schedule)
aws secretsmanager rotate-secret \
  --secret-id docker-cicd-labs/prod/app-credentials

# Describe the secret to see the new version stages
aws secretsmanager describe-secret \
  --secret-id docker-cicd-labs/prod/app-credentials \
  --query '{Versions: VersionIdsToStages, LastRotated: LastRotatedDate}'
```

### 10 — Teardown

```bash
cd security/lab-02-secrets-mgmt/terraform

# Destroy all resources (Lambda, OIDC role, rotation schedule)
terraform destroy

# Force-delete the secret immediately (bypasses the 7-day recovery window)
aws secretsmanager delete-secret \
  --secret-id docker-cicd-labs/prod/app-credentials \
  --force-delete-without-recovery
```

---

## Understanding checkpoints

**Q: Why not just store the DB password in a GitHub Secret?**
GitHub Secrets are CI-scoped, unrotated, and visible to any workflow in the repo.
Secrets Manager adds IAM-gated access, automatic rotation, and a per-call audit trail.
GitHub Secrets are appropriate for non-rotating CI config (like the role ARN); not for
application credentials.

**Q: What happens if someone opens a PR and tries to access prod secrets?**
The PR trigger is intentionally absent from the workflow. Even if someone added it,
the GitHub OIDC token for a PR has `sub = repo:<owner>/<repo>:pull_request`, which
does not match the IAM condition `ref:refs/heads/main`. `AssumeRoleWithWebIdentity`
is denied — no AWS credentials, no secret access.

**Q: What is `::add-mask::` and does it protect against log exfiltration?**
`::add-mask::` instructs the GitHub Actions runner to redact that string from all
log output in the current job. It prevents accidental logging but is not a
cryptographic guarantee — the secret is still in process memory. The real protection
is that temporary STS credentials expire in 1 hour and the secret is never written
to disk or stored in the image.

**Q: Why is the secret a single JSON entry instead of two separate secrets?**
Secrets Manager charges $0.40 per secret per month. One JSON object with two keys
costs $0.40 total; two separate secrets cost $0.80. The single-entry approach also
means a single IAM permission (`GetSecretValue` on one ARN) covers the full
credential set — simpler policy, same blast radius.

**Q: What does the rotation Lambda actually do in production?**
The stub in this lab logs the rotation steps without changing credentials. In
production you replace `_create_secret`, `_set_secret`, and `_test_secret` with
logic that generates a new password, applies it to the target service, and verifies
it works — before Secrets Manager promotes the new version to `AWSCURRENT`.

---

## Useful links

- [AWS Secrets Manager — Rotating secrets](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [GitHub Actions — Configuring OIDC in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [IAM OIDC condition keys for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect#filtering-for-a-specific-branch)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [boto3 — secretsmanager.get_secret_value](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/secretsmanager/client/get_secret_value.html)
- [CloudTrail — Logging Secrets Manager events](https://docs.aws.amazon.com/secretsmanager/latest/userguide/monitoring-cloudtrail.html)
- [GitHub Actions — Masking values in logs](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflows-do/workflow-commands-for-github-actions#masking-a-value-in-a-log)