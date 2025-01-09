variable "api_name" {
  description = "Name of the API"
  type        = string
}

variable "integration_target" {
  description = "Integration target for the API gateway (lambda or ECS)"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda function target ARN that runs the API"
  type        = string
}

variable "ecs_service_url" {
  description = "URL from the ECS service that runs the API"
  type        = string
}