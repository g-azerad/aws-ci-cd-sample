# Define IAM lambda role
resource "aws_iam_role" "lambda_role" {
  name               = "${var.api_name}-lambda-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach VPC access policy to the role
resource "aws_iam_role_policy_attachment" "lambda_vpc_policy" {
  role        = aws_iam_role.lambda_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Define policy to access secrets manager and attach it
data "aws_secretsmanager_secret" "db_user_secret" {
  name = var.db_user_secret_name
}

resource "aws_iam_policy" "lambda_secrets_policy" {
  name        = "${var.api_name}-secrets-policy"
  description = "Policy to access Secrets Manager"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "secretsmanager:GetSecretValue",
        Effect = "Allow",
        Resource = data.aws_secretsmanager_secret.db_user_secret.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_secrets_policy.arn
}

resource "aws_lambda_layer_version" "dependencies_layer" {
  layer_name          = "flask-dependencies"
  compatible_runtimes = [var.lambda_runtime]
  filename            = var.dependencies_package
}

resource "aws_lambda_function" "lambda" {
  function_name = "${var.api_name}-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  filename      = var.lambda_zip_file
  vpc_config {
    subnet_ids         = [var.public_subnet_id]
    security_group_ids = [var.security_group_id]
  }
  layers        = [aws_lambda_layer_version.dependencies_layer.arn]
  lifecycle {
    ignore_changes = [layers, filename]
  }
  environment {
    variables = {
      FLASK_ENV      = "production"
      DB_USER        = var.db_username
      DB_USER_SECRET = var.db_user_secret_name
      DB_HOST        = var.db_host
      DB_PORT        = var.db_port
      DB_NAME        = var.db_name
    }
  }
  tags = {
    Name = var.api_name
  }
}

resource "aws_lambda_function_url" "lambda_public_url" {
  function_name      = aws_lambda_function.lambda.arn
  authorization_type = "NONE"
}

# Define the lambda permission to interact with the API gateway
resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*"
}