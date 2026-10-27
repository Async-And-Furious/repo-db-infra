variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC id from repo-k8s-infra output"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DocumentDB subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach DocumentDB on 27017"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "HML-only DocumentDB ingress CIDRs"
  type        = list(string)
  default     = []
}

variable "instance_class" {
  description = "DocumentDB instance class (db.t4g.medium is the smallest available)"
  type        = string
  default     = "db.t4g.medium"
}

variable "final_snapshot_revision" {
  description = "Nonce for collision-safe PROD final snapshots"
  type        = string
}

variable "destroy_mode" {
  description = "Allow the controlled destroy path to disable deletion protection"
  type        = bool
  default     = false
}
