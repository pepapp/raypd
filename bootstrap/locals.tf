locals {
  name_prefix       = "sentinel-${var.owner}"
  state_bucket_name = "${local.name_prefix}-tfstate"
  state_bucket_arn  = "arn:aws:s3:::${local.state_bucket_name}"

  # Must match the name built in terraform/envs/poc (module "flow_logs_bucket").
  flow_logs_bucket_arn = "arn:aws:s3:::${local.name_prefix}-flow-logs-${var.account_id}"

  # Disjoint IAM namespaces:
  #   eks-<owner>-*          workload roles (cluster, nodes, LB controller) - CI manages these
  #   sentinel-<owner>-gha-* CI roles - created here, by a human; CI has NO rights on them
  # Because CI's IAM write permissions only match eks-<owner>-*, CI cannot modify or
  # escalate its own roles - no explicit Deny needed.
  workload_role_arn = "arn:aws:iam::${var.account_id}:role/eks-${var.owner}-*"

  ecr_repo_arn = "arn:aws:ecr:${var.region}:${var.account_id}:repository/${local.name_prefix}-*"

  eks_arns = flatten([for c in var.cluster_names : [
    "arn:aws:eks:${var.region}:${var.account_id}:cluster/${c}",
    "arn:aws:eks:${var.region}:${var.account_id}:*/${c}/*", # nodegroups, addons, access entries, pod identity
  ]])

  eks_log_group_arns = [for c in var.cluster_names :
    "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/eks/${c}/*"
  ]

  github_oidc_audience = "sts.amazonaws.com"

  tags = {
    Project     = "rapyd-sentinel"
    Environment = "shared"
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "bootstrap"
  }
}