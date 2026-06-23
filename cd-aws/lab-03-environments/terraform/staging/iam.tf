# ---------------------------------------------------------------------------
# Shared assume-role policy for ECS roles
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# ECS Execution Role
# ---------------------------------------------------------------------------
# Used by the ECS *agent* (not by your application code) to bootstrap a task:
#   - Pull the Docker image from ECR
#   - Write container stdout/stderr to CloudWatch Logs
#
# Think of it as: "what AWS permissions does ECS need to *start* my task?"
# ---------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  name               = "${var.project}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  description        = "ECS execution role (${var.environment}): ECR pull + CloudWatch Logs"
}

resource "aws_iam_role_policy_attachment" "execution_ecr_logs" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# ECS Task Role
# ---------------------------------------------------------------------------
# Used by the *application code running inside the container* at runtime.
# Separate per environment so a compromised staging task can never reach
# production resources, even if you later attach app permissions here.
#
# Think of it as: "what AWS permissions does my app need while it's running?"
# ---------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name               = "${var.project}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  description        = "ECS task role (${var.environment}): runtime permissions for the application"
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC — keyless authentication, scoped to the GitHub
# ENVIRONMENT (not just the branch)
# ---------------------------------------------------------------------------
# GitHub's OIDC token includes an `environment` claim whenever a job runs
# under `environment: <name>`. By matching on
# "repo:<owner>/<repo>:environment:<name>" instead of "...:ref:refs/heads/main"
# we get a stronger guarantee: this role can ONLY be assumed by a workflow run
# that GitHub has already gated through this environment's protection rules
# (required reviewer, wait timer, allowed branches). A workflow that bypasses
# the `environment:` key in its job — even on the main branch — cannot assume
# this role at all.
#
# This is the IAM-side enforcement that backs up the GitHub-side protection
# rules configured in Settings → Environments → production.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# The GitHub OIDC provider is created ONCE, in terraform/shared (it is a
# single resource per AWS account, and the shared module is applied before
# either environment). This module only REFERENCES it, read-only, via the
# shared module's remote state — see data.tf.
# ---------------------------------------------------------------------------

# IAM role that the GitHub Actions `deploy-staging` job assumes via OIDC.
resource "aws_iam_role" "github_actions" {
  name        = "${var.project}-github-actions-role"
  description = "Assumed by GitHub Actions via OIDC - scoped to the '${var.environment}' GitHub Environment only"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.shared.outputs.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # Locks this role to runs executed under the matching GitHub
            # Environment — this is the key difference from Lab 02, which
            # only matched on repo + wildcard branch.
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:${var.environment}"
          }
        }
      }
    ]
  })
}

# Permissions granted to the GitHub Actions role — scoped to THIS
# environment's ECR tag prefix is not possible (ECR is shared), so instead
# we scope ECS actions to this environment's cluster/service ARNs only.
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # Push/pull on the SHARED ECR repo. Both staging and production
        # roles get this same permission, because they push the same image.
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = data.terraform_remote_state.shared.outputs.ecr_repository_arn
      },
      {
        # RegisterTaskDefinition and DescribeTaskDefinition cannot be scoped
        # to a specific ARN (AWS API limitation — they operate before a
        # revision ARN exists). DescribeServices/UpdateService ARE scoped
        # below to this environment's own cluster and service only.
        Sid    = "ECSTaskDefinition"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
        ]
        Resource = "*"
      },
      {
        # Hard boundary: the staging role can only Describe/Update the
        # staging cluster+service ARNs, never production's — even though
        # both roles live in the same AWS account.
        Sid    = "ECSServiceDeployment"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
        ]
        Resource = [
          aws_ecs_cluster.main.arn,
          "arn:aws:ecs:${var.aws_region}:*:service/${aws_ecs_cluster.main.name}/${var.project}-service",
        ]
      },
      {
        Sid    = "PassRolesToECS"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.execution.arn,
          aws_iam_role.task.arn,
        ]
      },
      {
        Sid      = "ALBDescribe"
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:DescribeLoadBalancers"]
        Resource = "*"
      },
    ]
  })
}
