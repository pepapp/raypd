# AWS Load Balancer Controller: turns Services with loadBalancerClass service.k8s.aws/nlb
# into NLBs (IP targets, security groups from loadBalancerSourceRanges).
#
# Credentials via EKS Pod Identity (no IRSA - we can't create an OIDC provider in this account).

locals {
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  provider = aws.iam

  name               = var.role_name
  description        = "AWS Load Balancer Controller - ${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# The upstream policy for this controller version, vendored as-is:
#   https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.5.0/docs/install/iam_policy.json
# Inline, because iam:CreatePolicy isn't granted in this account.
resource "aws_iam_role_policy" "this" {
  provider = aws.iam

  name   = "aws-load-balancer-controller"
  role   = aws_iam_role.this.id
  policy = jsonencode(jsondecode(file("${path.module}/iam-policy.json"))) # minified: inline policies are capped at 10 KB
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = local.service_account
  role_arn        = aws_iam_role.this.arn
}

resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  namespace  = local.namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.region
    vpcId       = var.vpc_id
    serviceAccount = {
      create = true
      name   = local.service_account
    }
  })]

  # Waits until the controller (and its webhook) is ready - services with an NLB depend on it.
  atomic = true

  # The pod must find its Pod Identity association and policy on first start.
  depends_on = [aws_eks_pod_identity_association.this, aws_iam_role_policy.this]
}