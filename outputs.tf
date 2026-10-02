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

output "dynamodb_os_table_name" {
  value = module.dynamodb_read_model.os_table_name
}

output "dynamodb_cliente_table_name" {
  value = module.dynamodb_read_model.cliente_table_name
}

output "dynamodb_os_gsi_name" {
  value = module.dynamodb_read_model.os_gsi_name
}

output "dynamodb_irsa_role_arn" {
  description = "IAM role the OS Service service account (async-furious/os-service) assumes to reach DynamoDB"
  value       = module.dynamodb_read_model.irsa_role_arn
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
