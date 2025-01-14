resource "aws_api_gateway_rest_api" "api_gateway" {
  name          = var.api_name
}

# Generic resource /{proxy+}
resource "aws_api_gateway_resource" "counter_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "{proxy+}"
}

# ANY method for /counter endpoint and all the subpaths
resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.counter_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# The API integration depends from the target (lambda or ECS)
resource "aws_api_gateway_integration" "api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.counter_proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  type                    = var.integration_target == "lambda" ? "AWS_PROXY" : "HTTP_PROXY"
  integration_http_method = var.integration_target == "lambda" ? "POST" : "ANY"
  uri                     = var.integration_target == "lambda" ? var.lambda_invoke_arn : var.ecs_lb_uri
  connection_type         = var.integration_target == "ecs" ? "VPC_LINK" : null
  connection_id           = var.integration_target == "ecs" ? var.ecs_vpc_link_id : null
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# Defining deployment

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  depends_on = [
    aws_api_gateway_integration.api_integration
  ]
}

resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id           = aws_api_gateway_rest_api.api_gateway.id
  deployment_id         = aws_api_gateway_deployment.deployment.id
  stage_name            = "prod"
  description           = "Production stage"
  cache_cluster_enabled = false
}
