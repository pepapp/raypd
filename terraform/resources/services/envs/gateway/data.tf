data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_ecr_authorization_token" "this" {}

data "aws_lb" "backend_web" {
  name = "sentinel-backend-web"
}