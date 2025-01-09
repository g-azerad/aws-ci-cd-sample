output "db_endpoint" {
  description = "PostgreSQL RDS instance endpoint."
  value       = aws_db_instance.postgresql.endpoint
}

output "db_host" {
  description = "PostgreSQL RDS instance host."
  value       = aws_db_instance.postgresql.address
}
