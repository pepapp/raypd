variable "region" {
  description = "AWS region. The challenge IAM policy only allows us-east-2 for this user."
  type        = string
  default     = "us-east-2"
}

variable "account_id" {
  description = "Expected AWS account ID (guards against applying to the wrong account)."
  type        = string
  default     = "721500739616"
}

variable "owner" {
  description = "Short owner handle used to namespace globally-scoped names (IAM roles, S3 buckets) in the shared account."
  type        = string
  default     = "fadi"
}

variable "environment" {
  description = "Environment name, used for tagging."
  type        = string
  default     = "poc"
}