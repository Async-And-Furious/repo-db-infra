variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
  validation {
    condition     = contains(["hml", "prod"], var.environment)
    error_message = "environment must be exactly \"hml\" or \"prod\"."
  }
}

variable "destroy_mode" {
  description = "Use live HML K8s remote-state network outputs for an HML-only destroy"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "hml_public_subnet_ids" {
  description = "HML-only public subnet IDs, supplied per environment because the current K8s state does not publish them"
  type        = list(string)
  default     = []
}

variable "hml_allowed_cidr_blocks" {
  description = "Required HML-only PostgreSQL client CIDRs; never use a public catch-all"
  type        = list(string)
  default     = []
}

variable "prod_private_subnet_ids" {
  description = "Required PROD private subnet IDs owned by repo-k8s-infra"
  type        = list(string)
  default     = []
}

variable "prod_allowed_security_group_ids" {
  description = "Additional PROD consumer security groups"
  type        = list(string)
  default     = []
}

variable "prod_lambda_security_group_ids" {
  description = "PROD VPC Lambda consumer security groups"
  type        = list(string)
  default     = []
}

# Defaults keep an AWS Academy lab deployable without an SNS topic or a full set
# of tuning variables; override any of them per environment from CI.
variable "alarm_cpu_threshold" {
  type    = number
  default = 80
}
variable "alarm_free_storage_threshold_bytes" {
  description = "Free storage low-water mark in bytes (default 2 GiB)"
  type        = number
  default     = 2147483648
}
variable "alarm_connections_threshold" {
  type    = number
  default = 80
}
variable "alarm_actions" {
  description = "SNS topic ARNs notified on ALARM; empty means alarms are recorded but not routed"
  type        = list(string)
  default     = []
}
variable "alarm_ok_actions" {
  type    = list(string)
  default = []
}

variable "final_snapshot_revision" {
  description = "Explicit replacement nonce for collision-safe PROD final snapshots"
  type        = string
  default     = "1"

  validation {
    condition     = trimspace(var.final_snapshot_revision) != ""
    error_message = "final_snapshot_revision must be nonempty; increment it before a destructive replacement."
  }
}
