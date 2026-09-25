data "aws_vpc" "this" {
  tags = { Name = "vpc-${local.env}" }
}

module "lbc" {
  source = "../../../../modules/aws-lb-controller"
  providers = {
    aws     = aws
    aws.iam = aws.iam
    helm    = helm
  }

  cluster_name = local.cluster_name
  vpc_id       = data.aws_vpc.this.id
  region       = local.region
  role_name    = "eks-${local.owner}-${local.env}-lbc"
}