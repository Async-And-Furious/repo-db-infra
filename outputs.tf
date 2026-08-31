output "db_host" {
  description = "RDS hostname for the application connection"
  value       = module.rds.db_host
}

output "db_port" {
  description = "RDS PostgreSQL port for the application connection"
  value       = module.rds.db_port
}

output "db_name" {
  description = "Application database name"
  value       = module.rds.db_name
}

output "db_ssl_mode" {
  description = "Required PostgreSQL SSL mode for application clients"
  value       = "require"
}

output "db_security_group_id" {
  value = module.rds.db_security_group_id
}

output "db_secret_arn" {
  value     = module.rds.master_user_secret_arn
  sensitive = true
}

output "db_connection_secret_arn" {
  description = "Stable Secrets Manager identifier for the RDS-managed application credentials"
  value       = module.rds.master_user_secret_arn
  sensitive   = true
}

output "connection_contract" {
  value     = module.rds.connection_contract
  sensitive = true
}
