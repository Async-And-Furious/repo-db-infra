output "db_host" {
  description = "RDS instance endpoint address (without port)"
  value       = module.rds.db_host
}

output "db_port" {
  description = "RDS instance port"
  value       = module.rds.db_port
}

output "db_name" {
  description = "Default database name"
  value       = module.rds.db_name
}

output "db_security_group_id" {
  description = "Security group id guarding the RDS instance"
  value       = module.rds.db_security_group_id
}

# Never output raw credentials in plaintext.
# No db_secret_arn: AWS Secrets Manager is not viable under the AWS Academy lab
# account's default LabRole (see ADR-0002/0005 in repo-auth-serverless), so the
# password is only ever passed via Terraform variable, not exported.
