resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true # nodes talk to the API inside the VPC
    endpoint_public_access  = true # CI
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  # Access entries only (no aws-auth ConfigMap). The creator - the CI apply role -
  # becomes cluster admin; humans are added explicitly below.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  # Never drift into (paid) extended support silently.
  upgrade_policy {
    support_type = "STANDARD"
  }

  tags = var.tags
  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# --------------------------------------------------------------------------
# Add-ons. vpc-cni + kube-proxy go in before nodes so nodes join with the
# network-policy agent already configured; coredns + pod-identity-agent need
# nodes to schedule on.
# --------------------------------------------------------------------------
locals {
  addons_before_nodes = {
    "vpc-cni" = jsonencode({ enableNetworkPolicy = "true" }) # enforce Kubernetes NetworkPolicy
    "kube-proxy" = null
  }
  addons_after_nodes = ["coredns", "eks-pod-identity-agent"]
}

resource "aws_eks_addon" "before_nodes" {
  for_each = local.addons_before_nodes

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  configuration_values        = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids # private only - nodes get no public IPs

  ami_type       = var.node_ami_type
  capacity_type  = var.node_capacity_type
  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size

  scaling_config {
    min_size     = var.node_scaling.min
    desired_size = var.node_scaling.desired
    max_size     = var.node_scaling.max
  }

  update_config {
    max_unavailable = 1
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_eks_addon.before_nodes,
  ]
}

resource "aws_eks_addon" "after_nodes" {
  for_each = toset(local.addons_after_nodes)

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.default]
}

# Human access for kubectl
resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}