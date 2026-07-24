variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
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
