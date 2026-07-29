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

# db_secret_arn: pending RFC-006 (secrets strategy) — db_password is currently
# injected via TF_VAR_db_password (CI secret), not stored in Secrets Manager.
