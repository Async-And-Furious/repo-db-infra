variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
}

variable "db_name" {
  description = "Name of the default database created on the instance"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "16"
}

variable "publicly_accessible" {
  description = "Whether the RDS instance has a public endpoint. Required true in the AWS Academy lab account, since the default LabRole cannot be granted ec2:CreateNetworkInterface for VPC-attached Lambdas (see ADR-0005 in repo-auth-serverless)."
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Postgres (port 5432). Never default to 0.0.0.0/0."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC id from repo-k8s-infra output (optional; defaults to the account's default VPC when unset)"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Private subnet ids from repo-k8s-infra output (optional; unused while the RDS instance is publicly accessible)"
  type        = list(string)
  default     = []
}
