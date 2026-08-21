output "db_host" {
  description = "RDS instance endpoint address (without port)"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Default database name"
  value       = aws_db_instance.this.db_name
}

output "db_security_group_id" {
  description = "Security group id guarding the RDS instance"
  value       = aws_security_group.db.id
}
