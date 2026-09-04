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

variable "subnet_ids" {
  description = "Environment-selected subnet IDs"
  type        = list(string)

  validation {
    condition = length(var.subnet_ids) >= 2 && alltrue([
      for subnet_id in var.subnet_ids : subnet_id == trimspace(subnet_id) && trimspace(subnet_id) != ""
    ])
    error_message = "subnet_ids must contain at least two nonempty subnet IDs."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups (e.g. EKS nodes) allowed to reach the database on 5432"
  type        = list(string)
  default     = []

  validation {
    condition = (
      length(distinct([for security_group_id in var.allowed_security_group_ids : trimspace(security_group_id)])) == length(var.allowed_security_group_ids) &&
      alltrue([
        for security_group_id in var.allowed_security_group_ids : security_group_id == trimspace(security_group_id) && trimspace(security_group_id) != ""
      ])
    )
    error_message = "allowed_security_group_ids must contain unique, nonempty security group IDs."
  }
}

variable "allowed_cidr_blocks" {
  description = "HML-only PostgreSQL ingress CIDRs"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : cidr == trimspace(cidr) && trimspace(cidr) != "" &&
      can(cidrhost(cidr, 0)) && !can(regex("/0+$", cidr)) &&
      cidr != "0.0.0.0/0" && cidr != "::/0"
    ])
    error_message = "allowed_cidr_blocks must contain only well-formed, non-unrestricted CIDRs."
  }
}

variable "publicly_accessible" { type = bool }
variable "destroy_mode" {
  description = "Allow the controlled destroy path to disable deletion protection"
  type        = bool
  default     = false
}
variable "alarm_cpu_threshold" { type = number }
variable "alarm_free_storage_threshold_bytes" { type = number }
variable "alarm_connections_threshold" { type = number }
variable "alarm_actions" { type = list(string) }
variable "alarm_ok_actions" { type = list(string) }

variable "final_snapshot_revision" {
  description = "Explicit replacement nonce for collision-safe PROD final snapshots"
  type        = string

  validation {
    condition     = trimspace(var.final_snapshot_revision) != ""
    error_message = "final_snapshot_revision must be nonempty."
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
