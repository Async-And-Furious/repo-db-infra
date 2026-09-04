resource "aws_db_subnet_group" "this" {
  name       = "tc3-db-${var.environment}"
  subnet_ids = var.subnet_ids
}

resource "aws_db_parameter_group" "this" {
  name   = "tc3-db-${var.environment}-postgres16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
    # RDS records this one as pending-reboot. Leaving apply_method unset makes
    # Terraform default to "immediate" and propose reverting it on every plan.
    apply_method = "pending-reboot"
  }
}

resource "aws_security_group" "db" {
  name        = "tc3-db-${var.environment}"
  description = "Postgres ingress for the selected environment"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_security_group_ids) > 0 ? [true] : []
    content {
      description     = "Postgres from approved security groups"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = var.allowed_security_group_ids
    }
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [true] : []
    content {
      description = "Postgres from approved HML CIDRs"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  # PostgreSQL replies use stateful return traffic; the database has no outbound
  # dependency and therefore needs no permitted egress destinations. Declared as
  # an empty list rather than a block with no destinations: AWS creates no rule
  # for the latter, so Terraform proposed adding it on every single plan. The
  # empty list still suppresses the default allow-all rule, which omitting the
  # argument entirely would not do, since egress is Optional+Computed.
  egress = []

  lifecycle {
    precondition {
      condition = local.is_prod ? length(var.allowed_security_group_ids) > 0 && length(var.allowed_cidr_blocks) == 0 : (
        length(var.allowed_cidr_blocks) > 0 && length(var.allowed_security_group_ids) == 0
      )
      error_message = "HML requires CIDR-only PostgreSQL ingress; PROD requires security-group-only ingress."
    }
  }
}

resource "aws_db_instance" "this" {
  identifier     = "tc3-db-${var.environment}"
  engine         = "postgres"
  engine_version = "16.4"

  instance_class      = var.instance_class
  allocated_storage   = var.allocated_storage
  storage_encrypted   = true
  publicly_accessible = var.publicly_accessible

  db_name  = "workshop"
  username = "postgres"
  # RDS-managed master password (Secrets Manager), never in Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  # AWS Free Tier permits at most one day of automated backups.
  backup_retention_period    = local.is_prod ? 1 : 1
  auto_minor_version_upgrade = true
  multi_az                   = local.is_prod

  skip_final_snapshot       = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "tc3-db-${var.environment}-final-${random_id.final_snapshot.hex}" : null
  deletion_protection       = local.is_prod && !var.destroy_mode
  copy_tags_to_snapshot     = true

  lifecycle {
    postcondition {
      condition     = self.publicly_accessible == var.publicly_accessible
      error_message = "RDS public exposure must match the explicitly selected environment policy."
    }
    precondition {
      condition     = local.is_prod ? var.publicly_accessible == false : var.publicly_accessible == true
      error_message = "HML must be public and PROD must be private; this exception is HML-only."
    }
  }
}

resource "random_id" "final_snapshot" {
  byte_length = 4
  keepers = {
    environment             = var.environment
    final_snapshot_revision = var.final_snapshot_revision
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "tc3-db-${var.environment}-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_ok_actions
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.id }
}

resource "aws_cloudwatch_metric_alarm" "storage" {
  alarm_name          = "tc3-db-${var.environment}-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  threshold           = var.alarm_free_storage_threshold_bytes
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_ok_actions
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.id }
}

resource "aws_cloudwatch_metric_alarm" "connections" {
  alarm_name          = "tc3-db-${var.environment}-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.alarm_connections_threshold
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_ok_actions
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.id }
}

locals {
  is_prod = var.environment == "prod"
}
