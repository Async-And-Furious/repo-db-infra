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

variable "db_name" {
  description = "Name of the default database created on the RDS instance"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance (pass via .tfvars or CI secret, never commit)"
  type        = string
  sensitive   = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Postgres (port 5432). Never default to 0.0.0.0/0."
  type        = list(string)
  default     = []
}

