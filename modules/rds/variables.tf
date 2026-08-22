variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
  validation {
    condition     = contains(["hml", "prod"], var.environment)
    error_message = "environment must be exactly \"hml\" or \"prod\" — prod-only protections (multi_az, deletion_protection, final snapshot) are gated on this string matching exactly."
  }
}

variable "vpc_id" {
  description = "VPC id from repo-k8s-infra output"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet ids from repo-k8s-infra output"
  type        = list(string)

  validation {
    condition = length(var.private_subnet_ids) >= 2 && alltrue([
      for subnet_id in var.private_subnet_ids : subnet_id == trimspace(subnet_id) && trimspace(subnet_id) != ""
    ])
    error_message = "private_subnet_ids must contain at least two nonempty subnet IDs."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups (e.g. EKS nodes) allowed to reach the database on 5432"
  type        = list(string)
  default     = []

  validation {
    condition = (
      length(var.allowed_security_group_ids) > 0 &&
      length(distinct([for security_group_id in var.allowed_security_group_ids : trimspace(security_group_id)])) == length(var.allowed_security_group_ids) &&
      alltrue([
        for security_group_id in var.allowed_security_group_ids : security_group_id == trimspace(security_group_id) && trimspace(security_group_id) != ""
      ])
    )
    error_message = "allowed_security_group_ids must contain unique, nonempty security group IDs."
  }
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = trimspace(var.instance_class) != ""
    error_message = "instance_class must be nonempty."
  }
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage > 0
    error_message = "allocated_storage must be greater than zero."
  }
}
