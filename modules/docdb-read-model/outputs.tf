output "endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "port" {
  value = aws_docdb_cluster.this.port
}

output "database_name" {
  value = local.database_name
}

output "secret_arn" {
  value     = aws_secretsmanager_secret.docdb.arn
  sensitive = true
}

output "security_group_id" {
  value = aws_security_group.docdb.id
}

output "os_collection_name" {
  value = "os_read_model"
}

output "cliente_collection_name" {
  value = "cliente_read_model"
}
