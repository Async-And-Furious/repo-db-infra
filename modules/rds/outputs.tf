output "db_host" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the RDS-managed master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  sensitive   = true
}

output "connection_contract" {
  description = "Non-secret connection contract plus the Secrets Manager reference"
  value = {
    host              = aws_db_instance.this.address
    port              = aws_db_instance.this.port
    database          = aws_db_instance.this.db_name
    secret_arn        = aws_db_instance.this.master_user_secret[0].secret_arn
    security_group_id = aws_security_group.db.id
  }
  sensitive = true
}
