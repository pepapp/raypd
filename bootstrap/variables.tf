variable "region" {
  description = "AWS region (the challenge policy pins this user to us-east-2)."
  type        = string
  default     = "us-east-2"
}

variable "account_id" {
  description = "Expected AWS account ID."
  type        = string
  default     = "721500739616"
}

variable "owner" {
  description = "Short owner handle used to namespace IAM roles and buckets in the shared account. Must match terraform/envs/poc."
  type        = string
  default     = "fadi"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI roles, as owner/name. Case-sensitive: must match the OIDC 'sub' claim exactly."
  type        = string
  default     = "pepapp@48590188/raypd@1383292829"
}

variable "github_apply_branch" {
  description = "GitHub ONLY allowed branch to perform a TF apply"
  type        = string
  default     = "master"
}

variable "cluster_names" {
  description = "EKS cluster names the apply role may manage. Must match terraform/envs/poc."
  type        = list(string)
  default     = ["eks-gateway", "eks-backend"]
}

variable "allowed_managed_policy_arns" {
  description = "AWS-managed policies the apply role may attach to workload roles. Prevents CI from attaching e.g. AdministratorAccess."
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
  ]
}