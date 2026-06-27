# docker-cicd-labs

A progressive, hands-on collection of labs covering Docker, Docker Compose, and GitHub Actions CI/CD — built as a direct continuation of the [aws-labs](https://github.com/jbcampan/aws-labs) curriculum.

## Goal

Go from zero Docker knowledge to a fully automated CI/CD pipeline that builds, scans, and deploys containerized applications to AWS ECS Fargate on every push to `main` — using the tools actually used in production environments.

## Prerequisites

- AWS labs curriculum completed (IAM, VPC, EC2, CloudWatch, Lambda, ECS)
- Python and Bash fundamentals
- Docker Desktop (Mac/Windows) or Docker Engine (Linux)
- AWS CLI v2 configured (`aws configure`)
- Terraform >= 1.5
- A GitHub account with Actions enabled

## Tools used

| Tool | Usage |
|------|-------|
| **Docker** | Build and run containerized applications |
| **Docker Compose** | Orchestrate multi-service stacks locally |
| **GitHub Actions** | Automate CI/CD pipelines on push and pull request |
| **AWS ECR** | Private container registry |
| **AWS ECS Fargate** | Serverless container deployment |
| **Terraform** | Infrastructure as Code for AWS resources |
| **Trivy** | Container image vulnerability scanning |
| **AWS Secrets Manager** | Secrets storage and rotation |

## Cost

Labs are designed to minimize AWS spend. Resources that incur costs are explicitly flagged in each lab's README. All AWS resources should be destroyed after each lab.

Estimated total cost across the full curriculum: **< $5**.

Labs in Phases 1, 2, and 3 are entirely local — no AWS account required.

---

## Curriculum

### Phase 1 — Docker Fundamentals
> Build, run, debug, and optimize Docker images. Understand the core concepts before writing a single `docker-compose.yml`.

| Lab | Description |
|-----|-------------|
| lab-01-first-container | Lifecycle, layers, exec, logs — no Dockerfile yet |
| lab-02-dockerfile | Containerize a Python Flask app, understand layer caching |
| lab-03-multistage | Multi-stage build: from ~900 MB to ~80 MB |
| lab-04-volumes | Named volumes for persistence, bind mounts for dev live-reload |
| lab-05-networking | Two containers communicating via a custom bridge network and Docker DNS |

---

### Phase 2 — Docker Compose
> Orchestrate multi-service stacks locally. Replace chains of `docker run` with a single declarative file.

| Lab | Description |
|-----|-------------|
| lab-01-flask-redis | Flask + Redis: first `docker-compose.yml`, up/down/logs |
| lab-02-env-config | `.env` files, override files, dev/prod profiles |
| lab-03-full-stack | Node.js + PostgreSQL + Nginx with health checks and restart policies |
| lab-04-localstack | Simulate S3 and SQS locally with LocalStack — no AWS account needed |

---

### Phase 3 — GitHub Actions (CI)
> Automate tests, lint, and Docker builds on every push. A working CI pipeline is expected even for junior roles.

| Lab | Description |
|-----|-------------|
| lab-01-first-workflow | Push-triggered pipeline: checkout, setup Python, install, pytest |
| lab-02-matrix-lint | Parallel tests on Python 3.10 and 3.11, flake8 and black |
| lab-03-docker-build | Build Docker image in CI, push to GitHub Container Registry (GHCR) |
| lab-04-secrets-oidc | AWS credentials via OIDC — no long-term keys anywhere in the pipeline |

---

### Phase 4 — CD to AWS (ECR / ECS)
> Complete CI/CD pipeline: every push to `main` triggers tests → build → push ECR → deploy ECS. Production-grade pattern.

| Lab | Description |
|-----|-------------|
| lab-01-ecr-push | Terraform ECR with lifecycle policy, GitHub Actions push via OIDC |
| lab-02-ecs-deploy | ECS Fargate deployment: update task definition, force new deployment, wait for stability |
| lab-03-environments | Staging (automatic) and production (manual approval) with GitHub Environments |

> ⚠️ Phase 4 labs provision real AWS infrastructure. Destroy resources after each lab.

---

### Phase 5 — CI/CD Security
> Vulnerability scanning and zero-static-secret architecture. The baseline for any production pipeline.

| Lab | Description |
|-----|-------------|
| lab-01-trivy-scan | Trivy in CI: block deployment on CRITICAL CVE, SARIF report in GitHub Security |
| lab-02-secrets-mgmt | AWS Secrets Manager + OIDC: no static secrets anywhere in the chain |

> ⚠️ Phase 5 lab-02 uses AWS Secrets Manager (~$0.40/secret/month). Delete the secret after the lab.

---

## Repository structure

```
docker-cicd-labs/
├── docker/
│   ├── lab-01-first-container/
│   ├── lab-02-dockerfile/
│   ├── lab-03-multistage/
│   ├── lab-04-volumes/
│   └── lab-05-networking/
├── compose/
│   ├── lab-01-flask-redis/
│   ├── lab-02-env-config/
│   ├── lab-03-full-stack/
│   └── lab-04-localstack/
├── github-actions/
│   ├── lab-01-first-workflow/
│   ├── lab-02-matrix-lint/
│   ├── lab-03-docker-build/
│   └── lab-04-secrets-oidc/
├── cd-aws/
│   ├── lab-01-ecr-push/
│   ├── lab-02-ecs-deploy/
│   └── lab-03-environments/
└── security/
    ├── lab-01-trivy-scan/
    └── lab-02-secrets-mgmt/
```

Each lab follows the same structure:

```
lab-XX-name/
├── README.md
├── app/                        # Application code
├── Dockerfile                  # if applicable
├── docker-compose.yml          # if applicable
├── .dockerignore               # if applicable
├── .env.example                # if a .env is used
├── .github/
│   └── workflows/
│       └── ci.yml              # if applicable
└── terraform/                  # if AWS resources are needed
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

## How to use

Each lab is self-contained. The general workflow is:

```bash
cd <phase>/lab-XX-name

# For labs with Docker only
docker build -t my-app .
docker run -p 5000:5000 my-app

# For Compose labs
docker compose up --build
docker compose down

# For labs with Terraform
cd terraform
terraform init
terraform plan
terraform apply
# ... do the lab ...
terraform destroy
```

Refer to each lab's `README.md` for prerequisites, step-by-step instructions, and cleanup.

## What you will be able to do at the end

- Containerize any application and optimize its image for production
- Orchestrate a full multi-service stack locally with Docker Compose
- Set up a complete CI/CD pipeline on GitHub Actions from scratch
- Push Docker images automatically to AWS ECR using OIDC — no static credentials
- Deploy automatically to ECS Fargate on every push to `main`
- Block deployments on critical vulnerabilities with Trivy
- Manage secrets securely with AWS Secrets Manager and explain the architecture in an interview