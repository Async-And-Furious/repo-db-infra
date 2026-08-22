resource "aws_db_subnet_group" "this" {
  name       = "tc3-db-${var.environment}"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  name        = "tc3-db-${var.environment}"
  description = "Allow Postgres access from EKS node groups"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    # PostgreSQL replies use stateful return traffic; the database has no
    # outbound dependency and therefore needs no permitted egress destinations.
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  lifecycle {
    precondition {
      condition     = length(var.allowed_security_group_ids) > 0
      error_message = "At least one consumer security group must be allowed to reach PostgreSQL."
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
  publicly_accessible = false

  db_name  = "workshop"
  username = "postgres"
  # RDS-managed master password (Secrets Manager), never in Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period    = local.is_prod ? 7 : 1
  auto_minor_version_upgrade = true
  multi_az                   = local.is_prod

  skip_final_snapshot       = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "tc3-db-${var.environment}-final" : null
  deletion_protection       = local.is_prod
  copy_tags_to_snapshot     = true

  lifecycle {
    postcondition {
      condition     = self.publicly_accessible == false
      error_message = "The database must remain private; publicly_accessible cannot be enabled."
    }
  }
}

locals {
  is_prod = var.environment == "prod"
}
