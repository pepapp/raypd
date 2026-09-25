terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0"
      configuration_aliases = [aws.iam] # untagged provider for IAM (no iam:TagRole in this account)
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
  }
}