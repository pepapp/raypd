terraform {
  backend "s3" {
    bucket       = "sentinel-fadi-tfstate"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
