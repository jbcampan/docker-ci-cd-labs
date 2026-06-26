# ---------------------------------------------------------------------------
# Secrets Manager — application secret
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "app_secret" {
  name        = "${var.project_name}/prod/app-credentials"
  description = "Database connection string and third-party API key for ${var.project_name}"

  # Secrets Manager enforces a 7-day minimum recovery window.
  # Set to 0 only via the console override; Terraform minimum is 7.
  recovery_window_in_days = 7

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "app_secret_initial" {
  secret_id = aws_secretsmanager_secret.app_secret.id

  # JSON string containing both secrets in a single Secrets Manager entry.
  # One entry = one billing unit ($0.40/month) instead of two ($0.80/month).
  secret_string = jsonencode({
    db_connection_string = var.db_connection_string
    third_party_api_key  = var.third_party_api_key
  })

  # Prevent Terraform from overwriting the secret after the first apply
  # (rotation Lambda will manage subsequent versions).
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Enable automatic rotation every 30 days
resource "aws_secretsmanager_secret_rotation" "app_secret" {
  secret_id           = aws_secretsmanager_secret.app_secret.id
  rotation_lambda_arn = aws_lambda_function.secret_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_lambda_permission.secrets_manager_invoke]
}