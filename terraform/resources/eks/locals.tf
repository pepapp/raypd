locals {
  kubernetes_version = "1.35"
  owner = "fadi"
  admin_principal_arn = "arn:aws:iam::721500739616:user/fadi.saedih@gmail.com"
  eks_clusters = {
    gateway = { 
      name = "eks-gateway", 
      subnet_ids = data.aws_subnets.gateway_private.ids 
    }
    backend = { 
      name = "eks-backend", 
      subnet_ids = data.aws_subnets.backend_private.ids 
    }
  }

  default_tags = {
    Project     = "rapyd-sentinel"
    Environment = "poc"
    Owner       = "fadi"
    ManagedBy   = "terraform"
  }
}