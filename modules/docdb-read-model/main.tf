# Read model of the OS Service (ADR-0019, docs/architecture/persistence-model.md).
# This module owns the DocumentDB cluster and its credentials. Collections and
# indexes (os_read_model, cliente_read_model, the priority queue index) are
# created idempotently by the OS Service; rebuilding documents from PostgreSQL
# is a job in the OS Service code, not part of this module.
locals {
  is_prod       = var.environment == "prod"
  database_name = "os_read_model"
  username      = "docdb_os_service"
}

resource "aws_docdb_subnet_group" "this" {
  name       = "tc3-docdb-${var.environment}"
  subnet_ids = var.subnet_ids
}

resource "aws_docdb_cluster_parameter_group" "this" {
  name   = "tc3-docdb-${var.environment}-docdb5"
  family = "docdb5.0"

  parameter {
    name  = "tls"
    value = "enabled"
  }
}

resource "aws_security_group" "docdb" {
  name        = "tc3-docdb-${var.environment}"
  description = "DocumentDB ingress for the selected environment"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_security_group_ids) > 0 ? [true] : []
    content {
      description     = "DocumentDB from approved security groups"
      from_port       = 27017
      to_port         = 27017
      protocol        = "tcp"
      security_groups = var.allowed_security_group_ids
    }
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [true] : []
    content {
      description = "DocumentDB from approved HML CIDRs"
      from_port   = 27017
      to_port     = 27017
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  # Same stance as the RDS security group: replies are stateful and the cluster
  # has no outbound dependency; the empty list suppresses the default allow-all.
  egress = []
}

# No special characters: the password is passed to clients as a plain field.
resource "random_password" "docdb" {
  length  = 32
  special = false
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier              = "tc3-docdb-${var.environment}"
  engine                          = "docdb"
  engine_version                  = "5.0.0"
  master_username                 = local.username
  master_password                 = random_password.docdb.result
  db_subnet_group_name            = aws_docdb_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name
  storage_encrypted               = true

  backup_retention_period   = 1
  skip_final_snapshot       = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "tc3-docdb-${var.environment}-final-${var.final_snapshot_revision}" : null
  deletion_protection       = local.is_prod && !var.destroy_mode
}

# One instance: the read model is rebuildable from PostgreSQL, so no replica.
resource "aws_docdb_cluster_instance" "this" {
  identifier         = "tc3-docdb-${var.environment}-1"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class
}

resource "aws_secretsmanager_secret" "docdb" {
  name = "tc3-docdb-os-${var.environment}"
  # HML is torn down and recreated; a recovery window would block reusing the
  # secret name on the next up.
  recovery_window_in_days = local.is_prod ? 7 : 0
}

resource "aws_secretsmanager_secret_version" "docdb" {
  secret_id = aws_secretsmanager_secret.docdb.id
  secret_string = jsonencode({
    username = local.username
    password = random_password.docdb.result
    host     = aws_docdb_cluster.this.endpoint
    port     = aws_docdb_cluster.this.port
    dbname   = local.database_name
  })
}
