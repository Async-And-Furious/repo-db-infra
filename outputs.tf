output "db_host" {
  value = module.rds.db_host
}

output "db_port" {
  value = module.rds.db_port
}

output "db_name" {
  value = module.rds.db_name
}

output "db_security_group_id" {
  value = module.rds.db_security_group_id
}

output "db_secret_arn" {
  value = module.rds.master_user_secret_arn
}

output "db_connection_secret_arn" {
  description = "Secrets Manager ARN for consumers; credentials are never exposed in Terraform outputs"
  value       = module.rds.master_user_secret_arn
}

output "connection_contract" {
  value = module.rds.connection_contract
}
