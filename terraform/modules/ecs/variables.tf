variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
  default     = "ecs-prod"
}

variable "image_name" {
  description = "API image name on Docker Hub"
  type        = string
  default     = "counter-api"
}

variable "image_tag" {
  description = "API image tag"
  type        = string
  default     = "latest"
}

variable "public_subnet_id" {
  description = "Public subnet id for the Lambda."
  type        = string
}

variable "security_group_id" {
  description = "Security Group id for the Lambda."
  type        = string
}

variable "api_gateway_id" {
  description = "API gateway id for the Lambda integration"
  type        = string
}

variable "api_gateway_resource_id" {
  description = "API gateway resource id for the Lambda integration"
  type        = string
}