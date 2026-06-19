# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Access logs can be enabled here in production; skipped for cost in the lab.
  # enable_access_logs { bucket = "..." }

  tags = { Name = "${var.project}-alb" }
}

# ---------------------------------------------------------------------------
# Target Group — points at the Fargate tasks
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "app" {
  name        = "${var.project}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # required for Fargate (awsvpc network mode)

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30   # seconds between probes
    timeout             = 5    # seconds to wait for a response
    healthy_threshold   = 2    # consecutive successes → healthy
    unhealthy_threshold = 3    # consecutive failures → unhealthy
  }

  # During a rolling deployment ECS keeps the old task registered until the
  # new one passes health checks. "deregistration_delay" controls how long the
  # ALB drains in-flight requests from the old task before deregistering it.
  deregistration_delay = 30

  tags = { Name = "${var.project}-tg" }
}

# ---------------------------------------------------------------------------
# HTTP Listener — forwards all traffic to the target group
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
