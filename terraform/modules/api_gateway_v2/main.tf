# Define the API gateway V2 resource
resource "aws_apigatewayv2_api" "api_gateway" {
  name          = var.api_name
  protocol_type = "HTTP"
}

# Create a VPC link (only used by ECS integration)
resource "aws_apigatewayv2_vpc_link" "vpc_link" {
  count = var.integration_target == "ecs" ? 1 : 0

  name         = "${var.api_name}-ecs-vpc-link"
  subnet_ids         = [var.public_subnet_id]
  security_group_ids = [var.security_group_id]
}


# The API integration depends from the target (lambda or ECS)
resource "aws_apigatewayv2_integration" "lambda_integration" {
  count = var.integration_target == "lambda" ? 1 : 0

  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.lambda_invoke_arn
}

resource "aws_apigatewayv2_integration" "ecs_integration" {
  count = var.integration_target == "ecs" ? 1 : 0

  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "${var.ecs_lb_uri}/{proxy}"
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link[0].vpc_link.id

  request_parameters = {
    "overwrite:method.request.path.proxy" = "$request.path"
    "overwrite:method.request.header.X-HTTP-Method" = "$context.httpMethod"
  }
}

resource "aws_apigatewayv2_integration" "ecs_cloudmap_integration" {
  count = var.integration_target == "ecs_cloudmap" ? 1 : 0

  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.ecs_cloudmap_service_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link[0].vpc_link.id
  payload_format_version = "1.0"
}

# Definition of the route

resource "aws_apigatewayv2_route" "proxy_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "ANY /{proxy+}"

  target = var.integration_target == "lambda" ? 
    "integrations/${aws_apigatewayv2_integration.lambda_integration[0].id}" :
    var.integration_target == "ecs" ? 
    "integrations/${aws_apigatewayv2_integration.ecs_integration[0].id}" :
    "integrations/${aws_apigatewayv2_integration.ecs_cloudmap_integration[0].id}"
}

# Defining deployment with logging enabled

resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "live"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      requestTimeEpoch = "$context.requestTimeEpoch"
      path             = "$context.path"
      method           = "$context.httpMethod"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
    })
  }

  depends_on = [aws_cloudwatch_log_group.api_gateway_log_group]
}

resource "aws_iam_role" "api_gateway_logs_role" {
  name = "api-gateway-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_logs_policy" {
  role       = aws_iam_role.api_gateway_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/api_gateway/${var.api_name}"
  retention_in_days = 7
}
