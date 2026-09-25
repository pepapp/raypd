locals {
  owner        = "fadi"
  env          = basename(abspath(path.root))
  cluster_name = "eks-${local.env}"
  account_id   = "721500739616"
  region       = "us-east-2"
  registry     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"

  service_stack = {
    web = {
        version   = "0.1.0-gb3998d5"
        namespace = "web"
        values = {
            replicas = 2
            service = {
                loadBalancer = {
                    sourceRanges = ["10.10.0.0/20", "10.10.16.0/20"] # gateway private subnets = gateway nodes
                }
            }
        }
    }
  }

  default_tags = {
    Project     = "rapyd-sentinel"
    Environment = "poc"
    Owner       = "fadi"
    ManagedBy   = "terraform"
  }
}
