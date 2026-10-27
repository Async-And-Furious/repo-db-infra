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
  description = "Legacy alias of db_connection_secret_arn"
  value       = module.service_secrets.secret_arns["os"]
  sensitive   = true
}

output "db_connection_secret_arn" {
  description = "Secrets Manager ARN of the OS Service credentials (JSON username/password/host/port/dbname)"
  value       = module.service_secrets.secret_arns["os"]
  sensitive   = true
}

output "db_master_secret_arn" {
  description = "RDS-managed master credentials; used only by the bootstrap Job, never by an application"
  value       = module.rds.master_user_secret_arn
  sensitive   = true
}

output "db_billing_secret_arn" {
  description = "Secrets Manager ARN of the Billing Service credentials"
  value       = module.service_secrets.secret_arns["billing"]
  sensitive   = true
}

output "db_billing_name" {
  value = module.service_secrets.database_names["billing"]
}

output "db_execucao_secret_arn" {
  description = "Secrets Manager ARN of the Execucao e Producao credentials"
  value       = module.service_secrets.secret_arns["execucao"]
  sensitive   = true
}

output "db_execucao_name" {
  value = module.service_secrets.database_names["execucao"]
}

output "docdb_endpoint" {
  description = "DocumentDB cluster endpoint of the OS Service read model"
  value       = module.docdb_read_model.endpoint
}

output "docdb_port" {
  value = module.docdb_read_model.port
}

output "docdb_name" {
  description = "Database holding the read model collections"
  value       = module.docdb_read_model.database_name
}

output "docdb_secret_arn" {
  description = "Secrets Manager ARN of the DocumentDB credentials (JSON username/password/host/port/dbname)"
  value       = module.docdb_read_model.secret_arn
  sensitive   = true
}

output "docdb_os_collection_name" {
  value = module.docdb_read_model.os_collection_name
}

output "docdb_cliente_collection_name" {
  value = module.docdb_read_model.cliente_collection_name
}

output "connection_contract" {
  description = "Backward-compatible aggregate; secret_arn is the OS Service secret, never the master"
  value = {
    host              = module.rds.db_host
    port              = module.rds.db_port
    database          = module.rds.db_name
    ssl_mode          = "require"
    secret_arn        = module.service_secrets.secret_arns["os"]
    security_group_id = module.rds.db_security_group_id
  }
  sensitive = true
}
