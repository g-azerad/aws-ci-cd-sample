output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}

output "api_url" {
  value = aws_apigatewayv2_api.api_gateway.api_endpoint
}