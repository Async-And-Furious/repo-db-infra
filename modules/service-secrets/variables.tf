variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
}

variable "db_host" {
  description = "RDS hostname written into every service secret"
  type        = string
}

variable "db_port" {
  description = "RDS port written into every service secret"
  type        = number
}
