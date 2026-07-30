variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
  validation {
    condition     = contains(["hml", "prod"], var.environment)
    error_message = "environment must be exactly \"hml\" or \"prod\"."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC id from repo-k8s-infra output"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Private subnet ids from repo-k8s-infra output"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security groups (e.g. EKS nodes) allowed to reach the database on 5432"
  type        = list(string)
  default     = []
}
