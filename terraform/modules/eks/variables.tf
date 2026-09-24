variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version, e.g. \"1.33\". Pin explicitly; check what is in standard support with `aws eks describe-cluster-versions`."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs (at least two AZs) for the control-plane ENIs and the managed node group."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two AZs."
  }
}

variable "iam_role_prefix" {
  description = "Prefix for this cluster's IAM roles. Must fall inside the CI apply role's allowed namespace (eks-<owner>-*)."
  type        = string

  validation {
    condition     = startswith(var.iam_role_prefix, "eks-")
    error_message = "IAM roles in this account must start with eks- (or sentinel-)."
  }
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. GitHub-hosted runners have no stable IP range, hence 0.0.0.0/0 (IAM auth still required)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_ami_type" {
  description = "AMI type for the managed node group."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_capacity_type" {
  description = "Capacity type for the managed node group: ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  description = "Root EBS volume size (GiB) for managed node group instances."
  type        = number
  default     = 20
}

variable "node_scaling" {
  description = "Managed node group size. desired = 2 gives one node per AZ."
  type = object({
    min     = number
    desired = number
    max     = number
  })
  default = { min = 2, desired = 2, max = 3 }
}

variable "log_retention_days" {
  description = "Retention for control-plane logs (api, audit, authenticator)."
  type        = number
  default     = 7
}

variable "admin_principal_arns" {
  description = "Extra IAM principals granted cluster-admin via access entries (e.g. the operator's IAM user). The creator (CI apply role) is admin automatically - do not list it here."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags for taggable resources (merged with provider default_tags). Not applied to IAM roles."
  type        = map(string)
  default     = {}
}