#!/usr/bin/env bash
# setup-github-env.sh
#
# Creates the GitHub "staging" environment and populates its secrets
# using the GitHub CLI (gh). Run this AFTER terraform apply.
#
# Prerequisites:
#   - gh CLI installed and authenticated (gh auth login)
#   - terraform apply completed in ./terraform/
#   - GITHUB_REPO set to "org/repo" format
#
# Usage:
#   chmod +x app/setup-github-env.sh
#   GITHUB_REPO="my-org/docker-cicd-labs" ./app/setup-github-env.sh

set -euo pipefail
export MSYS_NO_PATHCONV=1

# ---------------------------------------------------------------------------
# Config — edit these or export them before running
# ---------------------------------------------------------------------------
GITHUB_REPO="${GITHUB_REPO:-}"
ENVIRONMENT_NAME="staging"
AWS_REGION="${AWS_REGION:-eu-west-3}"
TERRAFORM_DIR="$(dirname "$0")/../terraform"

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
if [[ -z "${GITHUB_REPO}" ]]; then
  echo "Error: GITHUB_REPO is not set."
  echo "Usage: GITHUB_REPO='org/repo' ./setup-github-env.sh"
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo "Error: GitHub CLI (gh) is not installed."
  echo "Install: https://cli.github.com/"
  exit 1
fi

if ! command -v terraform &>/dev/null; then
  echo "Error: terraform is not installed."
  exit 1
fi

echo "=== Reading Terraform outputs ==="
cd "${TERRAFORM_DIR}"

ROLE_ARN=$(terraform output -raw iam_role_arn)
echo "IAM Role ARN : ${ROLE_ARN}"
echo "AWS Region   : ${AWS_REGION}"
echo "Repository   : ${GITHUB_REPO}"
echo "Environment  : ${ENVIRONMENT_NAME}"
echo ""

# ---------------------------------------------------------------------------
# Create the GitHub environment (idempotent — gh will update if it exists)
# ---------------------------------------------------------------------------
echo "=== Creating GitHub environment '${ENVIRONMENT_NAME}' ==="
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${GITHUB_REPO}/environments/${ENVIRONMENT_NAME}" \
  --field wait_timer=0 \
  --silent
echo "✓ Environment created"

# ---------------------------------------------------------------------------
# Set environment secrets
# Secrets set here are ONLY available to jobs with `environment: staging`
# ---------------------------------------------------------------------------
echo ""
echo "=== Setting environment secrets ==="

gh secret set AWS_ROLE_ARN \
  --repo "${GITHUB_REPO}" \
  --env "${ENVIRONMENT_NAME}" \
  --body "${ROLE_ARN}"
echo "✓ AWS_ROLE_ARN set"

gh secret set AWS_REGION \
  --repo "${GITHUB_REPO}" \
  --env "${ENVIRONMENT_NAME}" \
  --body "${AWS_REGION}"
echo "✓ AWS_REGION set"

echo ""
echo "=== Summary ==="
echo "Environment '${ENVIRONMENT_NAME}' is ready."
echo ""
echo "Next step — add required reviewers (optional but recommended for prod):"
echo "  GitHub → Settings → Environments → staging → Required reviewers → add yourself"
echo ""
echo "Then trigger the workflow:"
echo "  gh workflow run github-actions-lab-04.yml --repo ${GITHUB_REPO}"
