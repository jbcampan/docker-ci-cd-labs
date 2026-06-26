data "archive_file" "rotation_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "secret_rotation" {
  function_name    = "${var.project_name}-secret-rotation"
  filename         = data.archive_file.rotation_lambda_zip.output_path
  source_code_hash = data.archive_file.rotation_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  handler          = "rotation_lambda.lambda_handler"
  role             = aws_iam_role.rotation_lambda.arn
  timeout          = 30

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# Allow Secrets Manager to invoke the rotation Lambda
resource "aws_lambda_permission" "secrets_manager_invoke" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secret_rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.app_secret.arn
}