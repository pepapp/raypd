provider "aws" {
  alias               = "aws-us-east-2"
  region              = "us-east-2"
  allowed_account_ids = ["721500739616"]

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias               = "iam"
  region              = "us-east-2"
  allowed_account_ids = ["721500739616"]
}