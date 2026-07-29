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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier     = "tc3-db-${var.environment}"
  engine         = "postgres"
  engine_version = "16.4"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = "workshop"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period    = var.environment == "prod" ? 7 : 1
  auto_minor_version_upgrade = true
  multi_az                   = var.environment == "prod"

  skip_final_snapshot = var.environment != "prod"
  deletion_protection = var.environment == "prod"
}
