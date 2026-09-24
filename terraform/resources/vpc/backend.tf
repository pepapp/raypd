terraform {
  backend "s3" {
    bucket       = "sentinel-fadi-tfstate"
    key          = "envs/poc/vpc.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
