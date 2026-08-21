provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "tc3"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "rds" {
  source = "./modules/rds"

  environment         = var.environment
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  vpc_id              = var.vpc_id
  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks
}
