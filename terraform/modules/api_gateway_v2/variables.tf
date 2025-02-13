variable "api_name" {
  description = "Name of the API"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet id for the running application."
  type        = string
}

variable "security_group_id" {
  description = "Security Group id for the running application."
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

variable "ecs_vpc_link_id" {
  description = "ARN from the VPC link targetting the load balancer handling the ECS that runs the API"
  type        = string
}

variable "ecs_lb_uri" {
  description = "URL of the load balancer in front of the ECS running the API"
  type        = string
}

variable "ecs_cloudmap_service_arn" {
  description = "ARN of the cloudmap service in front of the ECS running the API"
  type       = string
}
