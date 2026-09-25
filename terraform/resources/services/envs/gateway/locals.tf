locals {
  owner        = "fadi"
  env          = basename(abspath(path.root))
  cluster_name = "eks-${local.env}"
  account_id   = "721500739616"
  region       = "us-east-2"
  registry     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"

  service_stack = {
    haproxy = {
      version   = "1.0.0-g1e57286"
      namespace = "proxy"
      values = {
        haproxy = {
          config = templatefile("${path.module}/haproxy.cfg.tftpl", {
            backend_host = data.aws_lb.backend_web.dns_name
          })
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
