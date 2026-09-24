variable "region" {
  description = "AWS region. The challenge IAM policy only allows us-east-2 for this user."
  type        = string
  default     = "us-east-2"
}

variable "account_id" {
  description = "Expected AWS account ID (guards against applying to the wrong account)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "owner" {
  description = "Short owner handle used to namespace globally-scoped names (IAM roles, S3 buckets) in the shared account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.owner))
    error_message = "owner must be 2-8 lowercase alphanumerics."
  }
}

variable "environment" {
  description = "Environment name, used for tagging."
  type        = string
  default     = "poc"
}

variable "azs" {
  description = "Availability Zones used by both VPCs."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "gateway_vpc_cidr" {
  description = "CIDR for vpc-gateway."
  type        = string
  default     = "10.10.0.0/16"
}

variable "backend_vpc_cidr" {
  description = "CIDR for vpc-backend. Must not overlap gateway_vpc_cidr (VPC peering requirement)."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = var.backend_vpc_cidr != var.gateway_vpc_cidr
    error_message = "backend_vpc_cidr must differ from gateway_vpc_cidr."
  }
}

variable "single_nat_gateway" {
  description = "true = one NAT per VPC (cheaper). false = one NAT per AZ per VPC (HA)."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs in S3."
  type        = number
  default     = 30
}
