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

  environment                = var.environment
  vpc_id                     = var.vpc_id
  private_subnet_ids         = var.private_subnet_ids
  db_password                = var.db_password
  allowed_security_group_ids = var.allowed_security_group_ids
}
