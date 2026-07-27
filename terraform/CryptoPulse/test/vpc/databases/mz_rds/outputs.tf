output "database_endpoint" {
  description = "Database address:port"
  value       = aws_db_instance.postgresql.endpoint
}

output "database_address" {
  description = "Database Hostname"
  value       = aws_db_instance.postgresql.address
}