variable "environment" {
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "profile" {
  description = "AWS CLI profile"
  type        = string
}

variable "ssh_public_key" {
  description = "The SSH public key to access the EC2 instances."
  type        = string
}

variable "recovery_window" {
  description = "Number of days for the recovery window of secrets"
  type        = number
}

variable "db_master_user_secret_name" {
  description = "Secret name for the database master user"
  type        = string
}

variable "db_user_secret_name" {
  description = "Secret name for the database user"
  type        = string
}

variable "postgresql_version" {
  description = "PostgreSQL version for the database"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage for the database (GB)"
  type        = number
}

variable "backup_retention_period" {
  description = "Back-up retention period for the database (days)"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "counter_db"
}

variable "db_master_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_username" {
  description = "Database username for Lambda"
  type        = string
  default     = "user_db"
}

variable "db_port" {
  description = "Database access port"
  type        = number
  default     = 5432
}

variable "lambda_zip_file" {
  description = "Lambda application zip file location"
  type        = string
}

variable "dependencies_package" {
  description = "Lambda dependencies package zip file location"
  type        = string
}
