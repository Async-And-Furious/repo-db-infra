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

# TODO: wire modules/rds once database engine/version is approved (HANDOFF.md decision #6).
