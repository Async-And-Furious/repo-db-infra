# RDS module: instance, security group, backup/encryption.
# No Secrets Manager reference — the AWS Academy lab account's default LabRole
# cannot be granted secretsmanager:GetSecretValue on a scoped-down basis, so the
# password is passed in via Terraform variable (from CI secret / tfvars), never hardcoded.

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id == null ? true : null
}

resource "aws_security_group" "db" {
  name        = "tc3-db-${var.environment}"
  description = "Allow Postgres access to the tc3-db-${var.environment} RDS instance"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tc3-db-${var.environment}"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "tc3-db-${var.environment}"
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  publicly_accessible = var.publicly_accessible
  storage_encrypted   = true
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Name = "tc3-db-${var.environment}"
  }
}
