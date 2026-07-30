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
}

variable "allowed_security_group_ids" {
  description = "Security groups (e.g. EKS nodes) allowed to reach the database on 5432"
  type        = list(string)
  default     = []
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}
