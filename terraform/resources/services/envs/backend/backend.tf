terraform {
  backend "s3" {
    bucket       = "sentinel-fadi-tfstate"
    key          = "envs/poc/backend_services.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
