variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
  default     = "prod-ecs"
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
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

variable "db_user_secret_name" {
  description = "Name of the database secret in AWS Secrets Manager"
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "counter_db"
}

variable "db_username" {
  description = "Main username for the database"
  type        = string
  default     = "userdb"
}

variable "db_port" {
  description = "Port to access the database"
  type        = number
  default     = 5432
}

variable "db_host" {
  description = "Host address where the database is running"
  type        = string
}