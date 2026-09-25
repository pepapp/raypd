locals {
  owner        = "fadi"
  env          = basename(abspath(path.root))
  cluster_name = "eks-${local.env}"
  account_id   = "721500739616"
  region       = "us-east-2"
  registry     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"

  service_stack = {
    # haproxy = {
    #   version   = "0.1.0-gb3998d5"
    #   namespace = "proxy"
    # }
  }

  default_tags = {
    Project     = "rapyd-sentinel"
    Environment = "poc"
    Owner       = "fadi"
    ManagedBy   = "terraform"
  }
}
