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
  description = "Override for repo-k8s-infra's vpc_id output (normally read automatically via remote state)"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Override for repo-k8s-infra's private_subnet_ids output (normally read automatically via remote state)"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Extra security groups allowed to reach the database on 5432, in addition to repo-k8s-infra's EKS node group SG (read automatically via remote state)"
  type        = list(string)
  default     = []
}
