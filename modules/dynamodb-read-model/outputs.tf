output "os_table_name" {
  value = aws_dynamodb_table.os.name
}

output "cliente_table_name" {
  value = aws_dynamodb_table.cliente.name
}

output "os_gsi_name" {
  value = "gsi-fila-prioridade"
}

output "irsa_role_arn" {
  description = "Role the OS Service service account assumes; null when the cluster exposes no OIDC provider"
  value       = local.irsa_enabled ? aws_iam_role.os_service[0].arn : null
}
