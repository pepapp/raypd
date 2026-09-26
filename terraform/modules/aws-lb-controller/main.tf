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

  atomic = true

  # The pod must find its Pod Identity association and policy on first start.
  depends_on = [aws_eks_pod_identity_association.this, aws_iam_role_policy.this]
}