variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN from repo-k8s-infra; null skips the IRSA role"
  type        = string
  default     = null
}

variable "oidc_issuer_url" {
  description = "EKS OIDC issuer URL from repo-k8s-infra"
  type        = string
  default     = null
}

variable "service_account_namespace" {
  description = "Namespace of the OS Service service account"
  type        = string
  default     = "async-furious"
}

variable "service_account_name" {
  description = "Service account of the OS Service pod"
  type        = string
  default     = "os-service"
}
