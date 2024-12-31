output "db_endpoint" {
  description = "PostgreSQL RDS instance endpoint."
  value       = aws_db_instance.postgresql.endpoint
}
