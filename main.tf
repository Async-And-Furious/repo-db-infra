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

# RFC-004: repo-k8s-infra owns the VPC and publishes vpc_id/subnet/node-SG
# outputs. Read them from its state directly instead of requiring manual
# copy-paste into tfvars for every environment.
data "terraform_remote_state" "k8s_infra" {
  backend = "s3"

  config = {
    bucket = "tc3-terraform-state"
    key    = "repo-k8s-infra/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  vpc_id                     = coalesce(var.vpc_id, data.terraform_remote_state.k8s_infra.outputs.vpc_id)
  private_subnet_ids         = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.terraform_remote_state.k8s_infra.outputs.private_subnet_ids
  allowed_security_group_ids = distinct(concat(var.allowed_security_group_ids, var.lambda_security_group_ids, [data.terraform_remote_state.k8s_infra.outputs.node_security_group_id]))
}

module "rds" {
  source = "./modules/rds"

  environment                = var.environment
  vpc_id                     = local.vpc_id
  private_subnet_ids         = local.private_subnet_ids
  allowed_security_group_ids = local.allowed_security_group_ids
}
