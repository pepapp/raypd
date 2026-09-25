module "eks" {
  source   = "../../modules/eks"
  for_each = local.eks_clusters

  providers = {
    aws     = aws.aws-us-east-2
    aws.iam = aws.iam
  }

  cluster_name          = each.value.name
  kubernetes_version    = local.kubernetes_version
  subnet_ids            = sort(each.value.subnet_ids)
  iam_role_prefix       = "eks-${local.owner}-${each.key}"
  admin_principal_arns  = [local.admin_principal_arn]
  viewer_principal_arns = [local.viewer_principal_arns]
  tags                  = { Domain = each.key }
}