# ---------------------------------------------------------------------------
# CloudWatch Log Group
# Logs are streamed here by the awslogs driver in the task definition.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7 # keep logs 7 days — reduces cost for the lab

  tags = { Name = "${var.project}-logs" }
}

# ---------------------------------------------------------------------------
# ECS Cluster
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # enabled costs extra; disable for the lab
  }

  tags = { Name = "${var.project}-cluster" }
}

# ---------------------------------------------------------------------------
# ECS Task Definition — revision 1 (bootstrapped with var.app_version)
#
# GitHub Actions will create new revisions on every deployment by calling
# `aws ecs register-task-definition` with an updated image URI.
# Terraform manages only the baseline definition; subsequent revisions are
# owned by the CI/CD pipeline (hence `ignore_changes` on `container_definitions`).
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"  # required for Fargate
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${aws_ecr_repository.app.repository_url}:${var.app_version}"

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      # Runtime environment variables — non-sensitive values only.
      # Secrets (DB passwords, API keys) should use `secrets` + SSM/SecretsManager.
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "APP_VERSION", value = var.app_version },
        { name = "PORT", value = tostring(var.container_port) }
      ]

      # Logs are forwarded to CloudWatch via the awslogs driver.
      # The execution role must have logs:CreateLogStream / logs:PutLogEvents.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }

      # ECS will mark the task unhealthy (and replace it) if this check fails.
      # The ALB health check is separate and runs after the task is registered.
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15 # grace period for app startup
      }

      essential = true
    }
  ])

  # Allow GitHub Actions to register new revisions without Terraform
  # overwriting them on the next `terraform apply`.
  lifecycle {
    ignore_changes = [container_definitions]
  }

  tags = { Name = "${var.project}-task" }
}

# ---------------------------------------------------------------------------
# ECS Service — maintains `desired_count` running tasks behind the ALB.
#
# Rolling update strategy (default):
#   - minimum_healthy_percent = 100 → never drops below 1 task (no downtime)
#   - maximum_percent         = 200 → allows 2 tasks briefly during deployment
# ---------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name                               = "${var.project}-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60 # time ECS waits before checking ALB health

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true # needed in public subnet without NAT GW (cost saving)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Allow GitHub Actions (`aws ecs update-service --force-new-deployment`) to
  # change the running task definition without Terraform reverting it.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.execution_ecr_logs
  ]

  tags = { Name = "${var.project}-service" }
}

# ---------------------------------------------------------------------------
# Auto-generate task-definition.json for the GitHub Actions pipeline
# ---------------------------------------------------------------------------
# The `amazon-ecs-render-task-definition` action in the workflow needs a JSON
# file that represents the current task definition. Rather than maintaining it
# by hand (with placeholder ARNs), Terraform generates it automatically after
# `apply` using the real ARNs it just created.
#
# The file is written one level above the terraform/ directory so it sits at
# the lab root alongside the Dockerfile — exactly where the workflow expects it.
#
# The `image` field is set to the initial value here; the pipeline overwrites
# it with the real SHA-tagged URI at deploy time. This is intentional: the file
# in the repo is a *template*, not a live snapshot of what is running in ECS.
# ---------------------------------------------------------------------------
resource "local_file" "task_definition" {
  filename        = "${path.module}/../task-definition.json"
  file_permission = "0644"

  content = jsonencode({
    family                  = aws_ecs_task_definition.app.family
    requiresCompatibilities = ["FARGATE"]
    networkMode             = "awsvpc"
    cpu                     = tostring(var.task_cpu)
    memory                  = tostring(var.task_memory)
    executionRoleArn        = aws_iam_role.execution.arn
    taskRoleArn             = aws_iam_role.task.arn
    containerDefinitions = [
      {
        name      = "app"
        image     = "${aws_ecr_repository.app.repository_url}:${var.app_version}"
        essential = true
        portMappings = [
          {
            containerPort = var.container_port
            protocol      = "tcp"
          }
        ]
        environment = [
          { name = "ENVIRONMENT", value = var.environment },
          { name = "APP_VERSION", value = var.app_version },
          { name = "PORT",        value = tostring(var.container_port) }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.app.name
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = "app"
          }
        }
        healthCheck = {
          command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 15
        }
      }
    ]
  })
}
