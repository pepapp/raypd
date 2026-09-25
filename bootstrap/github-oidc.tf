data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ---------------------------------------------------------------------------
# Trust policies
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trust_plan" {
  statement {
    sid     = "GitHubOIDCAnyRefOfThisRepo"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [local.github_oidc_audience]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  statement {
    sid     = "GitHubOIDCMainBranchOnly"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [local.github_oidc_audience]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.github_apply_branch}"]
    }
  }
}

# ---------------------------------------------------------------------------
# Plan role: read-only
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "plan" {
  statement {
    sid = "ReadOnlyRegional"
    actions = [
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "ecr:Describe*",
      "ecr:List*",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy",
      "logs:Describe*",
      "logs:List*",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Refresh of the workload roles Terraform manages - nothing else in IAM.
  statement {
    sid       = "IamReadWorkloadRoles"
    actions   = ["iam:Get*", "iam:List*"]
    resources = [local.workload_role_arn]
  }

  statement {
    sid       = "StateRead"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  # envs/* only: CI cannot read the bootstrap state.
  statement {
    sid       = "StateObjectRead"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/envs/*"]
  }

  # Plans take the state lock, so the plan role may only write/delete lock files.
  statement {
    sid       = "StateLockOnly"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/envs/*.tflock"]
  }

  # Bucket-level config reads for the flow-logs bucket refresh. Bucket ARN only
  # (no "/*"), so s3:Get* cannot read any object in it.
  statement {
    sid       = "FlowLogsBucketConfigRead"
    actions   = ["s3:Get*", "s3:ListBucket"]
    resources = [local.flow_logs_bucket_arn]
  }

  statement {
    sid       = "PullCharts"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = ["arn:aws:ecr:${var.region}:${var.account_id}:repository/${local.name_prefix}-charts/*"]
  }

  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "gha_plan" {
  name                 = "${local.name_prefix}-gha-plan-v2"
  description          = "GitHub Actions (${var.github_repo}) - terraform plan / validation, read-only"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "gha_plan" {
  name   = "terraform-plan-readonly"
  role   = aws_iam_role.gha_plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# ---------------------------------------------------------------------------
# Apply role: a strict subset of the challenge's Candidates_Policy, scoped to
# this project's exact resources.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "apply" {
  # VPC, subnets, NAT, routes, peering, SGs, flow logs. ec2 resource-level scoping
  # is impractical (IDs unknown before create), so it's region-scoped instead.
  statement {
    sid       = "Networking"
    actions   = ["ec2:*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Only our two clusters and their sub-resources (node groups, add-ons,
  # access entries, pod identity associations).
  statement {
    sid       = "EksOurClustersOnly"
    actions   = ["eks:*"]
    resources = local.eks_arns
  }

  # EKS calls with no resource-level support (must be "*"): CreateCluster + reads.
  # CreateCluster is still constrained: it can only pass an eks-<owner>-* role.
  statement {
    sid = "EksUnscopableActions"
    actions = [
      "eks:CreateCluster",
      "eks:ListClusters",
      "eks:DescribeAddonVersions",
      "eks:DescribeAddonConfiguration",
      "eks:DescribeClusterVersions",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Container images: our repositories only; the auth token call has no resource.
  statement {
    sid       = "EcrOurRepos"
    actions   = ["ecr:*"]
    resources = [local.ecr_repo_arn]
  }

  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # EKS control-plane log groups (/aws/eks/<cluster>/cluster) - retention managed by TF.
  statement {
    sid       = "LogsEksControlPlane"
    actions   = ["logs:*"]
    resources = local.eks_log_group_arns
  }

  # DescribeLogGroups has no resource scoping; log-delivery calls are required
  # by the caller when creating VPC flow logs to S3.
  statement {
    sid = "LogsDescribeAndFlowLogDelivery"
    actions = [
      "logs:DescribeLogGroups",
      "logs:CreateLogDelivery",
      "logs:DeleteLogDelivery",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid       = "IamReadWorkloadRoles"
    actions   = ["iam:Get*", "iam:List*"]
    resources = [local.workload_role_arn]
  }

  statement {
    sid       = "ReadEksNodegroupServiceLinkedRole"
    actions   = ["iam:GetRole"]
    resources = ["arn:aws:iam::${var.account_id}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"]
  }

  statement {
    sid = "ManageWorkloadRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = [local.workload_role_arn]
  }

  # Only an allowlist of AWS-managed policies can be attached - CI cannot attach
  # AdministratorAccess (or anything else) to a role it creates.
  statement {
    sid       = "AttachAllowlistedManagedPolicies"
    actions   = ["iam:AttachRolePolicy"]
    resources = [local.workload_role_arn]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = var.allowed_managed_policy_arns
    }
  }

  # Cluster/node roles -> EKS; LB-controller role -> EKS Pod Identity.
  statement {
    sid       = "PassWorkloadRolesToEksOnly"
    actions   = ["iam:PassRole"]
    resources = [local.workload_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com", "pods.eks.amazonaws.com"]
    }
  }

  # --- Terraform state: read/write envs/* only (never the bootstrap state) ---
  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "StateReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.state_bucket_arn}/envs/*"]
  }

  statement {
    sid       = "StateLockRelease"
    actions   = ["s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/envs/*.tflock"]
  }

  # --- Flow-logs bucket: fully owned by the poc stack ---
  statement {
    sid       = "FlowLogsBucket"
    actions   = ["s3:*"]
    resources = [local.flow_logs_bucket_arn, "${local.flow_logs_bucket_arn}/*"]
  }
}

resource "aws_iam_role" "gha_apply" {
  name                 = "${local.name_prefix}-gha-apply-v2"
  description          = "GitHub Actions ${var.github_repo} ONLY from ${var.github_apply_branch} terraform apply + k8s deploy"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 7200 # two EKS clusters + node groups can exceed 1h on a cold apply
}

resource "aws_iam_role_policy" "gha_apply" {
  name   = "terraform-apply-scoped"
  role   = aws_iam_role.gha_apply.id
  policy = data.aws_iam_policy_document.apply.json
}