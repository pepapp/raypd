terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 6.0" }
    helm = { source = "hashicorp/helm", version = "~> 3.0" }
  }
}

provider "aws" {
  region              = local.region
  allowed_account_ids = [local.account_id]

  default_tags {
    tags = local.default_tags
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", local.region]
    }
  }

  registries = [{
    url      = "oci://${local.registry}"
    username = data.aws_ecr_authorization_token.this.user_name
    password = data.aws_ecr_authorization_token.this.password
  }]
}