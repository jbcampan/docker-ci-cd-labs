# ---------------------------------------------------------------------------
# CloudWatch Log Group
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7

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
# ECS Task Definition — revision 1 (bootstrapped with var.app_version).
#
# Image comes from the SHARED ECR repo (data.terraform_remote_state.shared),
# not from a per-environment repo. The pipeline pushes one image and deploys
# the exact same digest to staging first, then to production after approval.
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn        = aws_iam_role.execution.arn
  task_role_arn              = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${data.terraform_remote_state.shared.outputs.ecr_repository_uri}:${var.app_version}"

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      # The ENVIRONMENT variable is the only functional difference between
      # the staging and production containers — everything else (image,
      # CPU/memory, health check) is identical, as required by this lab.
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "APP_VERSION", value = var.app_version },
        { name = "PORT", value = tostring(var.container_port) }
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
# Auto-generate task-definition.production.json for the GitHub Actions pipeline
# ---------------------------------------------------------------------------
resource "local_file" "task_definition" {
  filename        = "${path.module}/../../task-definition.production.json"
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
        image     = "${data.terraform_remote_state.shared.outputs.ecr_repository_uri}:${var.app_version}"
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

# ---------------------------------------------------------------------------
# ECS Service
# ---------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name                               = "${var.project}-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60

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

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.execution_ecr_logs
  ]

  tags = { Name = "${var.project}-service" }
}
