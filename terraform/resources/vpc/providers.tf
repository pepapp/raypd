provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias               = "aws-us-east-2"
  region              = "us-east-2"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.default_tags
  }
}