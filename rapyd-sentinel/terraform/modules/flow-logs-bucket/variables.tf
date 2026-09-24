variable "bucket_name" {
  description = "Globally unique S3 bucket name for VPC flow logs."
  type        = string
}

variable "retention_days" {
  description = "Days to keep flow log objects before expiring them."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket. true for a PoC, false in production."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
