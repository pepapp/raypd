variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  description = "Passed to the controller so it doesn't need instance metadata (IMDS) to discover it."
  type        = string
}

variable "region" {
  type = string
}

variable "role_name" {
  description = "IAM role for the controller. Must start with eks- (the only prefixes CI may create)."
  type        = string

  validation {
    condition     = startswith(var.role_name, "eks-")
    error_message = "role_name must start with eks-."
  }
}

variable "chart_version" {
  description = "aws-load-balancer-controller chart version. iam-policy.json must come from the matching release."
  type        = string
  default     = "3.5.0"
}