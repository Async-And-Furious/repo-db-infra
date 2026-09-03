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

data "aws_caller_identity" "current" {}

# RFC-004: repo-k8s-infra owns the VPC and publishes vpc_id/subnet/node-SG
# outputs. Read them from its state directly instead of requiring manual
# copy-paste into tfvars for every environment.
data "terraform_remote_state" "k8s_infra" {
  backend = "s3"

  config = {
    bucket = "tc3-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "repo-k8s-infra/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  is_hml     = var.environment == "hml"
  vpc_id     = data.terraform_remote_state.k8s_infra.outputs.vpc_id
  subnet_ids = var.destroy_mode ? data.terraform_remote_state.k8s_infra.outputs.public_subnet_ids : (local.is_hml ? var.hml_public_subnet_ids : data.terraform_remote_state.k8s_infra.outputs.private_subnet_ids)
  allowed_security_group_ids = local.is_hml ? [] : distinct(concat(
    var.prod_allowed_security_group_ids,
    var.prod_lambda_security_group_ids,
    [data.terraform_remote_state.k8s_infra.outputs.node_security_group_id]
  ))
}

data "aws_vpc" "selected" {
  id = local.vpc_id
}

data "aws_subnet" "selected" {
  for_each = toset(local.subnet_ids)

  id = each.value
}

data "aws_route_table" "selected" {
  for_each = data.aws_subnet.selected

  subnet_id = each.value.id
}

locals {
  allowed_cidr_blocks = var.destroy_mode ? [data.aws_vpc.selected.cidr_block] : var.hml_allowed_cidr_blocks
  selected_availability_zones = distinct([
    for subnet in data.aws_subnet.selected : subnet.availability_zone
  ])
  selected_has_igw_route = {
    for subnet_id, route_table in data.aws_route_table.selected : subnet_id => anytrue([
      for route in route_table.routes : route.gateway_id != null && can(regex("^igw-", route.gateway_id))
    ])
  }
}

resource "terraform_data" "input_contract" {
  lifecycle {
    precondition {
      condition     = !var.destroy_mode || local.is_hml
      error_message = "destroy_mode is HML-only; production destroy is disabled."
    }
    precondition {
      condition = var.destroy_mode || (local.is_hml ? (
        length(var.hml_public_subnet_ids) >= 2 && length(var.hml_allowed_cidr_blocks) > 0 &&
        length(var.prod_allowed_security_group_ids) == 0 &&
        length(var.prod_lambda_security_group_ids) == 0
        ) : (
        length(local.subnet_ids) >= 2 &&
        length(var.hml_public_subnet_ids) == 0 && length(var.hml_allowed_cidr_blocks) == 0
      ))
      error_message = "Inputs must be environment-scoped: HML requires public subnets and allowed CIDRs; PROD rejects them and uses private subnets/security groups."
    }
    precondition {
      condition     = length(distinct(local.subnet_ids)) == length(local.subnet_ids) && length(local.selected_availability_zones) >= 2
      error_message = "Selected database subnets must be distinct and span at least two Availability Zones."
    }
    precondition {
      condition     = data.aws_vpc.selected.default == false
      error_message = "The selected database VPC must not be the default VPC."
    }
    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.selected : subnet.vpc_id == local.vpc_id])
      error_message = "Every selected database subnet must belong to the selected VPC."
    }
    precondition {
      condition     = alltrue([for route_table in data.aws_route_table.selected : route_table.vpc_id == local.vpc_id])
      error_message = "Every selected database route table must belong to the selected VPC."
    }
    precondition {
      condition = local.is_hml ? alltrue([
        for has_igw_route in values(local.selected_has_igw_route) : has_igw_route
        ]) : alltrue([
        for has_igw_route in values(local.selected_has_igw_route) : !has_igw_route
      ])
      error_message = "HML database subnets must have Internet Gateway routes; PROD database subnets must not have them."
    }
  }
}

module "rds" {
  source = "./modules/rds"

  environment                        = var.environment
  vpc_id                             = local.vpc_id
  subnet_ids                         = local.subnet_ids
  publicly_accessible                = local.is_hml
  allowed_security_group_ids         = local.allowed_security_group_ids
  allowed_cidr_blocks                = local.allowed_cidr_blocks
  alarm_cpu_threshold                = var.alarm_cpu_threshold
  alarm_free_storage_threshold_bytes = var.alarm_free_storage_threshold_bytes
  alarm_connections_threshold        = var.alarm_connections_threshold
  alarm_actions                      = var.alarm_actions
  alarm_ok_actions                   = var.alarm_ok_actions
  final_snapshot_revision            = var.final_snapshot_revision
}
