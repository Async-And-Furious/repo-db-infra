output "secret_arns" {
  description = "Secret ARN per service key (os, billing, execucao)"
  value       = { for key, secret in aws_secretsmanager_secret.service : key => secret.arn }
  sensitive   = true
}

output "database_names" {
  description = "Logical database name per service key"
  value       = { for key, service in local.services : key => service.dbname }
}
