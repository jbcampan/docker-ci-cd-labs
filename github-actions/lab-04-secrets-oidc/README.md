# Lab 04 — Secrets & Environments (OIDC)

## Objective

Authenticate GitHub Actions to AWS **without ever storing a long-term key**.  
GitHub proves its identity via a signed JWT (OIDC); AWS exchanges it for temporary STS credentials (lifetime: 1 h).

---

## Structure

```
docker-cicd-labs/                                   # repo root
├── .github/
│   └── workflows/
│       └── github-actions-lab-04.yml              # OIDC workflow
└── github-actions/
    └── lab-04-secrets-oidc/
        ├── README.md
        ├── app/
        │   └── setup-github-env.sh                # helper: creates GitHub env + secrets via gh CLI
        └── terraform/
            ├── .gitignore                         # excludes .tfstate, terraform.tfvars
            ├── main.tf                            # OIDC provider + IAM role + trust policy
            ├── variables.tf                       # github_org, github_repo, role_name…
            ├── outputs.tf                         # role ARN (to paste into GitHub)
            └── terraform.tfvars.example           # template to copy → terraform.tfvars
```

---

## What you create

| Resource | Description |
|---|---|
| `aws_iam_openid_connect_provider` | Registers GitHub as a trusted IdP in the AWS account |
| `aws_iam_role` (+ trust policy) | Role assumable only from the `staging` environment of THIS repo |
| `aws_iam_role_policy` | Grants `sts:GetCallerIdentity` (proof that auth works) |
| GitHub environment `staging` | Secret isolation scope + protection rules trigger point |
| Environment secrets | `AWS_ROLE_ARN`, `AWS_REGION` — visible only to jobs with `environment: staging` |

---

## What you learn

| Concept | Explanation |
|---|---|
| **OIDC (OpenID Connect)** | Federated identity protocol. GitHub issues a JWT signed with its private key. AWS verifies the signature using the CA thumbprint registered in the OIDC provider. |
| **`sts:AssumeRoleWithWebIdentity`** | STS action that exchanges an OIDC JWT for temporary credentials (`ASIA…`). No long-term key involved. |
| **Trust policy + `sub` condition** | AWS-side security lock: only the sub `repo:org/repo:environment:staging` can assume the role. Any other repo → denied. |
| **`id-token: write` permission** | Mandatory GitHub permission. Without it, GitHub will not issue the JWT and the action fails with a 403. |
| **Repo secrets vs environment secrets** | Repo secrets are accessible to all workflows. Environment secrets are scoped to a specific `environment:` and can be gated behind required reviewers. |
| **Protection rules** | GitHub mechanism requiring manual approval before a job with `environment: staging` starts. Ideal for production deployments. |
| **`ASIA` vs `AKIA` prefix** | `AKIA…` = long-term key (banned from CI). `ASIA…` = temporary STS token (best practice). |

---

## Estimated cost

**$0** — IAM, STS, and OIDC are free on AWS.  
⚠️ This lab requires an AWS account with sufficient permissions to create an OIDC provider and an IAM role.

---

## Prerequisites

| Tool | Minimum version | Check |
|---|---|---|
| Terraform | ≥ 1.6 | `terraform version` |
| AWS CLI | ≥ 2.x | `aws --version` |
| GitHub CLI | ≥ 2.x | `gh --version` |
| Local AWS credentials | IAM + STS rights | `aws sts get-caller-identity` |
| gh CLI authenticated | — | `gh auth status` |

---

## Steps

### 1 — Navigate to the Terraform directory

```bash
cd docker-cicd-labs/github-actions/lab-04-secrets-oidc/terraform
```

### 2 — Create `terraform.tfvars` from the example

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   github_org  = "your-username-or-org"
#   github_repo = "docker-cicd-labs"
```

### 3 — Initialise and apply Terraform

```bash
terraform init

# Review the plan before applying
terraform plan

# Create the OIDC provider + IAM role
terraform apply
# Type "yes" to confirm
```

> **Note:** if a GitHub OIDC provider already exists in your account (from a previous lab or
> another project), Terraform will error. In that case, import it:
> ```bash
> terraform import aws_iam_openid_connect_provider.github \
>   arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
> ```

### 4 — Retrieve the role ARN

```bash
terraform output iam_role_arn
# → arn:aws:iam::123456789012:role/github-actions-oidc-role
```

### 5 — Create the GitHub environment and its secrets (via the helper script)

```bash
cd ../app
chmod +x setup-github-env.sh

# Replace with your repo
GITHUB_REPO="your-org/docker-cicd-labs" ./setup-github-env.sh
```

> **Windows / Git Bash users:** Git Bash rewrites URL paths starting with `/` as filesystem
> paths. Add `export MSYS_NO_PATHCONV=1` at the top of the script (after `set -euo pipefail`)
> to disable this behaviour before running.

This script:
- creates the `staging` environment via the GitHub API
- injects `AWS_ROLE_ARN` and `AWS_REGION` as environment secrets

> **Manual alternative:**  
> GitHub → your repo → Settings → Environments → New environment → `staging`  
> then Secrets → Add secret → `AWS_ROLE_ARN` (value = Terraform output)  
> and → Add secret → `AWS_REGION` (e.g. `eu-west-3`)

### 6 — (Optional but recommended) Add a protection rule

```
GitHub → Settings → Environments → staging
  → Required reviewers → add your username
  → Save protection rules
```

The `verify-oidc` job will be paused until you approve it.

### 7 — Push the code and trigger the workflow

```bash
cd docker-cicd-labs   # repo root

git add .github/workflows/github-actions-lab-04.yml
git add github-actions/lab-04-secrets-oidc/
git commit -m "feat(lab-04): OIDC authentication GitHub Actions → AWS"
git push origin main
```

### 8 — Monitor the workflow

```bash
# Follow logs in real time
gh run watch --repo your-org/docker-cicd-labs

# Or trigger manually
gh workflow run github-actions-lab-04.yml --repo your-org/docker-cicd-labs
```

Expected output in the logs:

```
=== Assumed AWS identity ===
{
    "UserId": "AROA...:github-actions-lab04-12345678",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/github-actions-oidc-role/github-actions-lab04-12345678"
}

✓ Key prefix is ASIA → confirmed temporary STS credentials
✓ AWS_SESSION_TOKEN is set → temporary credentials confirmed
```

### 9 — Cleanup (optional)

```bash
cd github-actions/lab-04-secrets-oidc/terraform
terraform destroy
# Type "yes" to confirm
```

---

## Understanding checks

**Why is `id-token: write` mandatory?**  
Without this permission, GitHub refuses to issue the OIDC JWT for the workflow. It is a security measure: legacy workflows cannot inadvertently obtain AWS tokens.

**What happens if I remove the `sub` condition from the trust policy?**  
Any GitHub Actions workflow — in any repository — could assume the role. This is a critical vulnerability. The `sub` condition is the primary security lock.

**Why an environment secret rather than a repo secret?**  
A repo secret is accessible to all workflows in the repo, including PRs from forks. An environment secret is only injected into jobs that declare `environment: staging`, and can be gated behind a manual approval.

**How long do the credentials last?**  
1 hour (`max_session_duration = 3600`). If your jobs routinely run longer, increase this value in `main.tf` (AWS maximum: 12 h). The effective duration is the minimum between `max_session_duration` and the `role-duration-seconds` parameter passed to the action.

**How does Terraform handle the OIDC provider if another lab already created one?**  
Only one GitHub OIDC provider can exist per AWS account. If you run this lab in an account where one already exists, use `terraform import` (see Step 3).

---

## Useful links

- [GitHub Docs — Configuring OIDC in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [AWS Docs — Creating OIDC identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [AWS Docs — AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)
- [GitHub Docs — Using environments for deployment](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment)
- [GitHub Docs — Secrets (repo vs environment)](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions)