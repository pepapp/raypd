terraform {
  backend "s3" {
    bucket       = "sentinel-fadi-tfstate"
    key          = "envs/poc/ecr.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
