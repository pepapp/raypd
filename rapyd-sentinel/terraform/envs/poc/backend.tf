# Remote state: S3 with native lockfile locking (no DynamoDB table needed).
# The bucket is created by ../../../bootstrap (applied once by the bootstrap workflow).
#
# Local plans before the bucket exists:
#   cp backend_override.tf.example backend_override.tf   (git-ignored)
terraform {
  backend "s3" {
    bucket       = "sentinel-fadi-tfstate"
    key          = "envs/poc/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
